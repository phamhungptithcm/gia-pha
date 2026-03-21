import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';

const repoRoot = path.resolve(__dirname, '..', '..', '..', '..');
const firestoreRulesPath = path.join(repoRoot, 'firebase', 'firestore.rules');
const storageRulesPath = path.join(repoRoot, 'firebase', 'storage.rules');

const firestoreRules = readFileSync(firestoreRulesPath, 'utf8');
const storageRules = readFileSync(storageRulesPath, 'utf8');

test('firestore rules hardening contract: users/device token schemas are allowlisted', () => {
  assert.match(
    firestoreRules,
    /function validUserProfileWrite\(userId\)\s*\{[\s\S]*?keys\(\)\.hasOnly\(\[[\s\S]*?'subscription'[\s\S]*?'entitlements'[\s\S]*?\]\)/,
  );
  assert.match(
    firestoreRules,
    /function validDeviceTokenWrite\(userId\)\s*\{[\s\S]*?keys\(\)\.hasOnly\(\[[\s\S]*?'lastSeenAt'[\s\S]*?\]\)/,
  );
});

test('firestore rules hardening contract: branch-scoped member update cannot switch clan', () => {
  assert.match(
    firestoreRules,
    /isBranchScopedMemberManager\([\s\S]*?\)\s*&&\s*request\.resource\.data\.clanId == resource\.data\.clanId/,
  );
});

test('firestore rules hardening contract: mutable clan resources enforce immutable clanId on update', () => {
  for (const collectionName of [
    'branches',
    'events',
    'funds',
    'scholarshipPrograms',
    'awardLevels',
    'invites',
  ]) {
    assert.match(
      firestoreRules,
      new RegExp(
        `match \\/${collectionName}\\/\\{[^}]+\\}[\\s\\S]*?allow create:[\\s\\S]*?allow update:[\\s\\S]*?request\\.resource\\.data\\.clanId == resource\\.data\\.clanId`,
      ),
    );
  }
});

test('storage rules hardening contract: generic writes and evidence writes validate payload shape', () => {
  assert.match(
    storageRules,
    /function isValidWritePayload\(maxBytes\)/,
  );
  assert.match(
    storageRules,
    /match \/clans\/\{clanId\}\/\{allPaths=\*\*\}[\s\S]*?isValidWritePayload\(25 \* 1024 \* 1024\)/,
  );
  assert.match(
    storageRules,
    /match \/clans\/\{clanId\}\/scholarship\/evidence\/\{memberId\}\/\{fileName\}[\s\S]*?isValidWritePayload\(20 \* 1024 \* 1024\)/,
  );
  assert.match(
    storageRules,
    /match \/submissions\/\{clanId\}\/\{memberId\}\/\{fileName\}[\s\S]*?isValidWritePayload\(20 \* 1024 \* 1024\)/,
  );
});
