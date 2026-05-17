import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { deleteObject, ref, uploadBytes } from "firebase/storage";
import { doc, setDoc, updateDoc } from "firebase/firestore";

const repoRoot = path.resolve(__dirname, "..", "..", "..", "..");
const firestoreRules = readFileSync(
  path.join(repoRoot, "firebase", "firestore.rules"),
  "utf8",
);
const storageRules = readFileSync(
  path.join(repoRoot, "firebase", "storage.rules"),
  "utf8",
);

const [firestoreHost, firestorePort] = (
  process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080"
).split(":");
const [storageHost, storagePort] = (
  process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? "127.0.0.1:9199"
).split(":");

const clanId = "clan-demo";
const branchId = "branch-main";
const memberId = "member-main";

const clanAdminClaims = {
  clanIds: [clanId],
  memberId,
  branchId,
  primaryRole: "CLAN_ADMIN",
  memberAccessMode: "claimed",
};

const branchAdminClaims = {
  clanIds: [clanId],
  memberId,
  branchId,
  primaryRole: "BRANCH_ADMIN",
  memberAccessMode: "claimed",
};

const memberClaims = {
  clanIds: [clanId],
  memberId,
  branchId,
  primaryRole: "MEMBER",
  memberAccessMode: "claimed",
};

const childAdminClaims = {
  clanIds: [clanId],
  memberId,
  branchId,
  primaryRole: "CLAN_ADMIN",
  memberAccessMode: "child",
};

let rulesEnv: RulesTestEnvironment;

test.before(async () => {
  rulesEnv = await initializeTestEnvironment({
    projectId: `befam-rules-${randomUUID()}`,
    firestore: {
      rules: firestoreRules,
      host: firestoreHost,
      port: Number(firestorePort),
    },
    storage: {
      rules: storageRules,
      host: storageHost,
      port: Number(storagePort),
    },
  });
});

test.after(async () => {
  await rulesEnv.cleanup();
});

test.afterEach(async () => {
  await rulesEnv.clearFirestore();
});

async function seedBaseDocuments() {
  await rulesEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "clans", clanId), {
      id: clanId,
      status: "active",
      ownerUid: "owner-uid",
    });
    await setDoc(doc(db, "clans", "clan-other"), {
      id: "clan-other",
      status: "active",
      ownerUid: "owner-other",
    });
    await setDoc(doc(db, "branches", branchId), {
      id: branchId,
      clanId,
      name: "Main branch",
    });
  });
}

test("firestore runtime: event update cannot switch clanId", async () => {
  await seedBaseDocuments();

  await rulesEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "events", "event-1"), {
      id: "event-1",
      clanId,
      title: "Ancestor memorial",
      startsAt: "2026-03-20T10:00:00.000Z",
    });
  });

  const actor = rulesEnv
    .authenticatedContext("admin-uid", clanAdminClaims)
    .firestore();
  await assertSucceeds(
    updateDoc(doc(actor, "events", "event-1"), {
      title: "Updated title",
    }),
  );
  await assertFails(
    updateDoc(doc(actor, "events", "event-1"), {
      clanId: "clan-other",
    }),
  );
});

test("firestore runtime: branch admin cannot move a member to another clan", async () => {
  await seedBaseDocuments();

  await rulesEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "members", "member-1"), {
      id: "member-1",
      clanId,
      branchId,
      fullName: "Le Van A",
      authUid: "member-auth-uid",
      primaryRole: "MEMBER",
      updatedBy: "seed",
    });
  });

  const branchAdminDb = rulesEnv
    .authenticatedContext("branch-admin-uid", branchAdminClaims)
    .firestore();
  await assertSucceeds(
    updateDoc(doc(branchAdminDb, "members", "member-1"), {
      fullName: "Le Van A Updated",
      updatedBy: "branch-admin-uid",
    }),
  );
  await assertFails(
    updateDoc(doc(branchAdminDb, "members", "member-1"), {
      clanId: "clan-other",
    }),
  );
  await assertFails(
    updateDoc(doc(branchAdminDb, "members", "member-1"), {
      primaryRole: "CLAN_ADMIN",
    }),
  );
  await assertFails(
    updateDoc(doc(branchAdminDb, "members", "member-1"), {
      parentIds: ["member-parent"],
    }),
  );
});

test("firestore runtime: child sessions cannot use inherited admin role claims", async () => {
  await seedBaseDocuments();

  await rulesEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "members", "member-1"), {
      id: "member-1",
      clanId,
      branchId,
      fullName: "Le Van A",
      authUid: "child-uid",
      primaryRole: "CLAN_ADMIN",
      updatedBy: "seed",
    });
  });

  const childDb = rulesEnv
    .authenticatedContext("child-uid", childAdminClaims)
    .firestore();
  await assertFails(
    updateDoc(doc(childDb, "clans", clanId), {
      name: "Blocked child edit",
    }),
  );
  await assertFails(
    updateDoc(doc(childDb, "members", "member-1"), {
      fullName: "Blocked child member edit",
      updatedBy: "child-uid",
    }),
  );
  await assertFails(
    setDoc(doc(childDb, "relationships", "rel-child-1"), {
      id: "rel-child-1",
      clanId,
      personA: "member-parent",
      personB: "member-1",
      type: "parent_child",
      status: "active",
    }),
  );
  await assertFails(
    setDoc(doc(childDb, "events", "event-child-1"), {
      id: "event-child-1",
      clanId,
      title: "Blocked child event",
    }),
  );
});

test("firestore runtime: direct relationship writes are server-only", async () => {
  await seedBaseDocuments();

  const adminDb = rulesEnv
    .authenticatedContext("admin-uid", clanAdminClaims)
    .firestore();
  await assertFails(
    setDoc(doc(adminDb, "relationships", "rel-direct-1"), {
      id: "rel-direct-1",
      clanId,
      personA: "member-parent",
      personB: "member-child",
      type: "parent_child",
      status: "active",
    }),
  );
});

test("firestore runtime: user cannot mutate subscription/entitlements/normalizedPhone", async () => {
  await seedBaseDocuments();

  await rulesEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users", "user-1"), {
      uid: "user-1",
      memberId,
      clanId,
      clanIds: [clanId],
      branchId,
      primaryRole: "CLAN_ADMIN",
      accessMode: "claimed",
      linkedAuthUid: true,
      normalizedPhone: "+84901234567",
      email: "demo@befam.vn",
      languageCode: "vi",
      locale: "vi",
      subscription: {
        planCode: "BASE",
      },
      entitlements: {
        canUseAdsFree: false,
      },
      updatedAt: "2026-03-20T10:00:00.000Z",
      createdAt: "2026-03-20T10:00:00.000Z",
    });
  });

  const userDb = rulesEnv
    .authenticatedContext("user-1", clanAdminClaims)
    .firestore();
  await assertSucceeds(
    updateDoc(doc(userDb, "users", "user-1"), {
      locale: "en",
      updatedAt: "2026-03-20T11:00:00.000Z",
    }),
  );
  await assertFails(
    updateDoc(doc(userDb, "users", "user-1"), {
      entitlements: {
        canUseAdsFree: true,
      },
    }),
  );
  await assertFails(
    updateDoc(doc(userDb, "users", "user-1"), {
      normalizedPhone: "+84909999999",
    }),
  );
});

test("firestore runtime: first user create cannot seed billing entitlements", async () => {
  await seedBaseDocuments();

  const userClaims = {
    clanIds: [clanId],
    memberId,
    branchId,
    primaryRole: "MEMBER",
    memberAccessMode: "claimed",
  };
  const userDb = rulesEnv
    .authenticatedContext("new-user", userClaims)
    .firestore();
  const baseUser = {
    uid: "new-user",
    memberId,
    clanId,
    clanIds: [clanId],
    branchId,
    primaryRole: "MEMBER",
    accessMode: "claimed",
    linkedAuthUid: true,
    email: "new@befam.vn",
    languageCode: "vi",
    locale: "vi",
    updatedAt: "2026-03-20T10:00:00.000Z",
    createdAt: "2026-03-20T10:00:00.000Z",
  };

  await assertSucceeds(setDoc(doc(userDb, "users", "new-user"), baseUser));
  await rulesEnv.clearFirestore();
  await seedBaseDocuments();
  await assertFails(
    setDoc(doc(userDb, "users", "new-user"), {
      ...baseUser,
      subscription: {
        planCode: "PRO",
      },
      entitlements: {
        adFree: true,
      },
    }),
  );
});

test("firestore runtime: notification isRead update accepts only boolean", async () => {
  await seedBaseDocuments();

  await rulesEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "notifications", "notif-1"), {
      id: "notif-1",
      clanId,
      memberId,
      message: "New event reminder",
      isRead: false,
      createdAt: "2026-03-20T10:00:00.000Z",
    });
  });

  const memberDb = rulesEnv
    .authenticatedContext("member-uid", memberClaims)
    .firestore();
  await assertSucceeds(
    updateDoc(doc(memberDb, "notifications", "notif-1"), {
      isRead: true,
    }),
  );
  await assertFails(
    updateDoc(doc(memberDb, "notifications", "notif-1"), {
      isRead: "true",
    }),
  );
});

test("storage runtime: owner avatar upload + delete are allowed", async () => {
  await seedBaseDocuments();

  const memberStorage = rulesEnv
    .authenticatedContext("member-uid", memberClaims)
    .storage();
  const avatarRef = ref(
    memberStorage,
    `clans/${clanId}/members/${memberId}/avatar/demo.jpg`,
  );

  await assertSucceeds(
    uploadBytes(avatarRef, Buffer.from("avatar-image"), {
      contentType: "image/jpeg",
    }),
  );
  await assertSucceeds(deleteObject(avatarRef));
});

test("storage runtime: child sessions cannot use inherited admin role claims", async () => {
  await seedBaseDocuments();

  const childStorage = rulesEnv
    .authenticatedContext("child-uid", childAdminClaims)
    .storage();
  const avatarRef = ref(
    childStorage,
    `clans/${clanId}/members/${memberId}/avatar/child.jpg`,
  );
  const genericRef = ref(childStorage, `clans/${clanId}/documents/child.txt`);

  await assertFails(
    uploadBytes(avatarRef, Buffer.from("avatar-image"), {
      contentType: "image/jpeg",
    }),
  );
  await assertFails(
    uploadBytes(genericRef, Buffer.from("blocked"), {
      contentType: "text/plain",
    }),
  );
});

test("storage runtime: generic clan path rejects payload larger than max bytes", async () => {
  await seedBaseDocuments();

  const adminStorage = rulesEnv
    .authenticatedContext("admin-uid", clanAdminClaims)
    .storage();
  const validRef = ref(adminStorage, `clans/${clanId}/documents/ok.txt`);
  const oversizedRef = ref(
    adminStorage,
    `clans/${clanId}/documents/too-large.bin`,
  );

  await assertSucceeds(
    uploadBytes(validRef, Buffer.from("ok"), {
      contentType: "text/plain",
    }),
  );

  const oversizedBytes = new Uint8Array(26 * 1024 * 1024);
  await assertFails(
    uploadBytes(oversizedRef, oversizedBytes, {
      contentType: "application/octet-stream",
    }),
  );
});
