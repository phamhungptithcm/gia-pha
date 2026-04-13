import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { genkit, z } from "genkit";
import { googleAI } from "@genkit-ai/google-genai";

import {
  AI_ASSIST_ENABLED,
  AI_ASSIST_MODEL,
  AI_ASSIST_TIMEOUT_MS,
  AI_FEATURE_COOLDOWN_MS,
  APP_REGION,
  CALLABLE_ENFORCE_APP_CHECK,
  getAiApiKey,
} from "../config/runtime";
import {
  buildEntitlementFromSubscription,
  loadSubscription,
} from "../billing/store";
import { requireAuth } from "../shared/errors";
import { db } from "../shared/firestore";
import { logInfo, logWarn } from "../shared/logger";
import {
  GOVERNANCE_ROLES,
  ensureAnyRole,
  ensureClaimedSession,
  ensureClanAccess,
  stringOrNull,
  tokenClanIds,
  tokenMemberId,
  tokenPrimaryRole,
  type AuthToken,
} from "../shared/permissions";

const GOOGLE_GENAI_API_KEY_SECRET = defineSecret("GOOGLE_GENAI_API_KEY");

const APP_CHECK_CALLABLE_OPTIONS = {
  region: APP_REGION,
  enforceAppCheck: CALLABLE_ENFORCE_APP_CHECK,
  // Restrict Gemini API key access to AI callables only.
  secrets: [GOOGLE_GENAI_API_KEY_SECRET],
};

const aiFeatureThrottleCollection = db.collection("aiFeatureThrottle");
const clansCollection = db.collection("clans");

const ProfileReviewSchema = z.object({
  summary: z.string(),
  strengths: z.array(z.string()).max(3),
  missingImportant: z.array(z.string()).max(4),
  risks: z.array(z.string()).max(3),
  nextActions: z.array(z.string()).max(3),
});

const EventCopySchema = z.object({
  title: z.string(),
  description: z.string(),
  recommendedReminderOffsetsMinutes: z.array(z.coerce.number().int()).max(4),
  rationale: z.array(z.string()).max(3),
});

const DuplicateExplanationSchema = z.object({
  summary: z.string(),
  topSignals: z.array(z.string()).max(4),
  reviewChecklist: z.array(z.string()).max(4),
  recommendedAction: z.enum(["review_first", "safe_to_override", "uncertain"]),
});

const AppAssistantReplySchema = z.object({
  answer: z.string(),
  steps: z.array(z.string()).max(4),
  quickReplies: z.array(z.string()).max(3),
  caution: z.string(),
  suggestedDestination: z.enum([
    "home",
    "tree",
    "events",
    "billing",
    "profile",
    "none",
  ]),
});

type ProfileReview = z.infer<typeof ProfileReviewSchema>;
type EventCopySuggestion = z.infer<typeof EventCopySchema>;
type DuplicateExplanation = z.infer<typeof DuplicateExplanationSchema>;
type AppAssistantReply = z.infer<typeof AppAssistantReplySchema>;

type ProfileDraftInput = {
  fullName: string;
  nickName: string;
  jobTitle: string;
  hasPhone: boolean;
  hasEmail: boolean;
  hasAddress: boolean;
  bioWordCount: number;
  socialLinkCount: number;
};

type EventDraftInput = {
  clanId: string;
  eventType: string;
  title: string;
  description: string;
  locationName: string;
  hasLocationAddress: boolean;
  startsAtIso: string;
  timezone: string;
  isRecurring: boolean;
};

type DuplicateCandidateInput = {
  clanId: string;
  genealogyName: string;
  leaderName: string;
  provinceCity: string;
  score: number;
  summary: string;
  memberCount: number | null;
};

type DuplicateExplanationInput = {
  clanId: string;
  genealogyName: string;
  founderName: string;
  countryCode: string;
  description: string;
  candidates: Array<DuplicateCandidateInput>;
};

type AppAssistantHistoryMessage = {
  role: "user" | "assistant";
  text: string;
};

type AppAssistantInput = {
  clanId: string;
  currentScreenId: "home" | "tree" | "events" | "billing" | "profile";
  currentScreenTitle: string;
  activeClanName: string;
  question: string;
  history: Array<AppAssistantHistoryMessage>;
};

type StructuredAiResult<T> = {
  output: T;
  usedFallback: boolean;
  model: string | null;
  elapsedMs: number;
  fallbackReason: AiFallbackReason | null;
};

type AiFallbackReason =
  | "disabled"
  | "timeout"
  | "invalid_output"
  | "generation_error";

let cachedAiClient: ReturnType<typeof genkit> | null = null;
let cachedAiApiKey = "";

export const reviewProfileDraftAi = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);

    const locale = normalizeLocale(optionalString(request.data, "locale"));
    const clanId = resolveClanId(
      auth.token,
      optionalString(request.data, "clanId"),
    );
    ensureClanAccess(auth.token, clanId);
    const draft = readProfileDraftInput(request.data);
    const traceId = `ai_profile_${Date.now()}`;
    await enforceAiFeatureThrottle({
      uid: auth.uid,
      clanId,
      feature: "profile_review",
      locale,
      traceId,
    });

    const fallback = buildProfileFallback(locale, draft);
    const result = await maybeGenerateStructured({
      clanId,
      uid: auth.uid,
      authToken: auth.token,
      feature: "profile_review",
      locale,
      traceId,
      schema: ProfileReviewSchema,
      fallback,
      system: buildSystemInstruction(locale),
      prompt: [
        localized(
          locale,
          "Bạn là trợ lý thận trọng cho ứng dụng gia phả BeFam. Chỉ đưa ra gợi ý tư vấn, không khẳng định dữ kiện chưa có. Ưu tiên các góp ý giúp hồ sơ dễ được nhận diện và đáng tin hơn với gia đình.",
          "You are a conservative assistant for the BeFam genealogy app. Provide advisory suggestions only and never invent facts. Prioritize advice that makes the profile easier for relatives to recognize and trust.",
        ),
        localized(
          locale,
          "Hãy đọc tín hiệu hồ sơ nháp bên dưới và trả về: 1 câu tóm tắt ngắn, tối đa 3 điểm mạnh, tối đa 4 mục còn thiếu quan trọng, tối đa 3 rủi ro/chỗ chưa rõ, và tối đa 3 bước tiếp theo cụ thể. Chỉ dựa vào dữ liệu có sẵn, không suy đoán các chi tiết cá nhân chưa được gửi lên.",
          "Review the draft profile signals below and return: one short summary sentence, up to 3 strengths, up to 4 important missing items, up to 3 risks/ambiguities, and up to 3 concrete next steps. Only rely on the provided data and do not infer personal details that were not shared.",
        ),
        `PROFILE_DRAFT_JSON:\n${JSON.stringify(draft, null, 2)}`,
      ].join("\n\n"),
    });

    return {
      ...result.output,
      usedFallback: result.usedFallback,
      model: result.model,
    };
  },
);

export const draftEventCopyAi = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);

    const locale = normalizeLocale(optionalString(request.data, "locale"));
    const draft = readEventDraftInput(request.data);
    ensureClanAccess(auth.token, draft.clanId);
    const traceId = `ai_event_${Date.now()}`;
    await enforceAiFeatureThrottle({
      uid: auth.uid,
      clanId: draft.clanId,
      feature: "event_copy",
      locale,
      traceId,
    });

    const fallback = buildEventCopyFallback(locale, draft);
    const result = await maybeGenerateStructured({
      clanId: draft.clanId,
      uid: auth.uid,
      authToken: auth.token,
      feature: "event_copy",
      locale,
      traceId,
      schema: EventCopySchema,
      fallback,
      system: buildSystemInstruction(locale),
      prompt: [
        localized(
          locale,
          "Bạn là trợ lý soạn nội dung sự kiện cho ứng dụng gia phả. Hãy viết ngắn, rõ, ấm áp, tránh sáo rỗng và tránh phóng đại. Nếu là sự kiện tưởng niệm, giữ giọng điệu trang trọng.",
          "You are an event copy assistant for a genealogy app. Write concise, clear, warm copy without exaggeration or generic fluff. If the event is memorial-related, keep the tone respectful.",
        ),
        localized(
          locale,
          "Dựa trên dữ liệu sự kiện tối thiểu, hãy đề xuất tiêu đề, mô tả ngắn phù hợp để hiển thị trong app, 2-4 mốc nhắc lịch thực dụng, và vài lý do ngắn cho lựa chọn đó. Không bịa thêm tên người, địa chỉ chi tiết, hoặc thông tin chưa có trong JSON.",
          "Based on the minimal event data, suggest a suitable title, a short in-app description, 2-4 practical reminder offsets, and a few short reasons for those choices. Do not invent person names, detailed addresses, or any information not present in the JSON.",
        ),
        `EVENT_DRAFT_JSON:\n${JSON.stringify(draft, null, 2)}`,
      ].join("\n\n"),
    });

    return {
      ...result.output,
      recommendedReminderOffsetsMinutes: sanitizeReminderOffsets(
        result.output.recommendedReminderOffsetsMinutes,
      ),
      usedFallback: result.usedFallback,
      model: result.model,
    };
  },
);

export const explainDuplicateGenealogyAi = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);
    ensureAnyRole(
      auth.token,
      [
        GOVERNANCE_ROLES.superAdmin,
        GOVERNANCE_ROLES.clanAdmin,
        GOVERNANCE_ROLES.adminSupport,
      ],
      "Only governance setup roles can request duplicate-genealogy AI guidance.",
    );

    const locale = normalizeLocale(optionalString(request.data, "locale"));
    const input = readDuplicateExplanationInput(request.data);
    const clanId = resolveClanId(
      auth.token,
      optionalString(request.data, "clanId"),
    );
    ensureClanAccess(auth.token, clanId);
    const traceId = `ai_duplicate_${Date.now()}`;
    await enforceAiFeatureThrottle({
      uid: auth.uid,
      clanId,
      feature: "duplicate_genealogy",
      locale,
      traceId,
    });

    const fallback = buildDuplicateExplanationFallback(locale, input);
    const result = await maybeGenerateStructured({
      clanId,
      uid: auth.uid,
      authToken: auth.token,
      feature: "duplicate_genealogy",
      locale,
      traceId,
      schema: DuplicateExplanationSchema,
      fallback,
      system: buildSystemInstruction(locale),
      prompt: [
        localized(
          locale,
          "Bạn đang hỗ trợ quản trị gia phả đánh giá nguy cơ tạo trùng. Chỉ giải thích tín hiệu đáng ngờ và checklist rà soát; không ra quyết định thay con người.",
          "You are helping genealogy admins assess possible duplicate creation. Explain suspicious signals and a review checklist only; do not make the decision for the human reviewer.",
        ),
        localized(
          locale,
          "Dựa trên hồ sơ gia phả mới và các ứng viên hiện có, hãy tóm tắt mức độ rủi ro trùng, nêu các tín hiệu chính, checklist kiểm tra, và khuyến nghị: review_first, safe_to_override, hoặc uncertain.",
          "Based on the new genealogy draft and existing candidates, summarize duplicate risk, list the main signals, provide a review checklist, and recommend one of: review_first, safe_to_override, or uncertain.",
        ),
        `DUPLICATE_INPUT_JSON:\n${JSON.stringify(input, null, 2)}`,
      ].join("\n\n"),
    });

    return {
      ...result.output,
      usedFallback: result.usedFallback,
      model: result.model,
    };
  },
);

export const chatWithAppAssistantAi = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);

    const locale = normalizeLocale(optionalString(request.data, "locale"));
    const input = readAppAssistantInput(request.data);
    ensureClanAccess(auth.token, input.clanId);
    await ensurePremiumAssistantAccess({
      uid: auth.uid,
      clanId: input.clanId,
      locale,
    });

    const traceId = `ai_app_assistant_${Date.now()}`;
    await enforceAiFeatureThrottle({
      uid: auth.uid,
      clanId: input.clanId,
      feature: "app_assistant_chat",
      locale,
      traceId,
    });
    const fallback = buildAppAssistantFallback(locale, input);
    const result = await maybeGenerateStructured({
      clanId: input.clanId,
      uid: auth.uid,
      authToken: auth.token,
      feature: "app_assistant_chat",
      locale,
      traceId,
      schema: AppAssistantReplySchema,
      fallback,
      system: buildSystemInstruction(locale),
      prompt: [
        localized(
          locale,
          "Bạn là trợ lý hỗ trợ sử dụng app BeFam. Chỉ trả lời về cách dùng app, quy trình gia phả, sự kiện, hồ sơ, gói dịch vụ và những thao tác có thật trong app. Không hứa các tính năng chưa tồn tại, không bịa dữ liệu và không nói lan man.",
          "You are the BeFam in-app assistant. Answer only about using the app, genealogy workflows, events, profile management, billing, and flows that genuinely exist in the app. Never promise unavailable features, invent data, or ramble.",
        ),
        localized(
          locale,
          "Hãy trả lời ngắn, thực dụng, ưu tiên 2-4 bước thao tác. Nếu người dùng hỏi ngoài phạm vi app, hãy nói rõ và kéo họ về thao tác gần nhất trong BeFam. Nếu cần điều hướng, chỉ chọn một đích trong home/tree/events/billing/profile hoặc none.",
          "Keep the answer concise and practical, prioritizing 2-4 actionable steps. If the request is outside the app scope, say so and redirect them to the closest BeFam workflow. If navigation would help, choose exactly one destination from home/tree/events/billing/profile or none.",
        ),
        localized(
          locale,
          "Các khu vực chính của app: home (tổng quan và lối tắt), tree (gia phả và quan hệ), events (lịch song song, sự kiện, giỗ kỵ), billing (gói dịch vụ và thanh toán), profile (hồ sơ, cài đặt, ngôn ngữ).",
          "Main app areas: home (overview and shortcuts), tree (genealogy and relationships), events (dual calendar, events, memorial rituals), billing (plans and payments), profile (profile, settings, language).",
        ),
        `APP_CONTEXT_JSON:\n${JSON.stringify(
          {
            clanId: input.clanId,
            currentScreenId: input.currentScreenId,
            currentScreenTitle: input.currentScreenTitle,
            activeClanName: input.activeClanName,
            role: tokenPrimaryRole(auth.token),
          },
          null,
          2,
        )}`,
        `CONVERSATION_HISTORY_JSON:\n${JSON.stringify(input.history, null, 2)}`,
        `USER_QUESTION:\n${input.question}`,
      ].join("\n\n"),
    });

    return {
      ...result.output,
      usedFallback: result.usedFallback,
      model: result.model,
    };
  },
);

class AiTimeoutError extends Error {
  constructor(timeoutMs: number) {
    super(`AI generation timed out after ${timeoutMs}ms.`);
    this.name = "AiTimeoutError";
  }
}

export async function runAiTaskWithFallback<T>(input: {
  task: () => Promise<T>;
  fallback: T;
  timeoutMs: number;
}): Promise<{
  output: T;
  usedFallback: boolean;
  elapsedMs: number;
  fallbackReason: Exclude<AiFallbackReason, "disabled"> | null;
}> {
  const startedAt = Date.now();
  let timeoutHandle: NodeJS.Timeout | undefined;

  try {
    const output = await Promise.race([
      input.task(),
      new Promise<T>((_, reject) => {
        timeoutHandle = setTimeout(() => {
          reject(new AiTimeoutError(input.timeoutMs));
        }, input.timeoutMs);
      }),
    ]);
    return {
      output,
      usedFallback: false,
      elapsedMs: Date.now() - startedAt,
      fallbackReason: null,
    };
  } catch (error) {
    return {
      output: input.fallback,
      usedFallback: true,
      elapsedMs: Date.now() - startedAt,
      fallbackReason: normalizeAiFallbackReason(error),
    };
  } finally {
    if (timeoutHandle != null) {
      clearTimeout(timeoutHandle);
    }
  }
}

async function maybeGenerateStructured<T>(input: {
  clanId: string;
  uid: string;
  authToken: AuthToken;
  feature: string;
  locale: string;
  traceId: string;
  schema: z.ZodType<T>;
  fallback: T;
  system: string;
  prompt: string;
}): Promise<StructuredAiResult<T>> {
  const aiClient = getAiClient();
  if (aiClient == null) {
    const result: StructuredAiResult<T> = {
      output: input.fallback,
      usedFallback: true,
      model: null,
      elapsedMs: 0,
      fallbackReason: "disabled",
    };
    logAiExecution({
      clanId: input.clanId,
      uid: input.uid,
      authToken: input.authToken,
      feature: input.feature,
      locale: input.locale,
      traceId: input.traceId,
      result,
    });
    return result;
  }

  const runtimeResult = await runAiTaskWithFallback<T>({
    fallback: input.fallback,
    timeoutMs: AI_ASSIST_TIMEOUT_MS,
    task: async () => {
      const response = await aiClient.generate({
        model: `googleai/${AI_ASSIST_MODEL}`,
        system: input.system,
        prompt: input.prompt,
        output: { schema: input.schema },
        config: {
          temperature: 0.25,
          maxOutputTokens: 750,
        },
      });

      if (response.output == null) {
        throw new Error("AI response did not match the expected schema.");
      }

      return response.output;
    },
  });

  const result: StructuredAiResult<T> = {
    output: runtimeResult.output,
    usedFallback: runtimeResult.usedFallback,
    model: AI_ASSIST_MODEL,
    elapsedMs: runtimeResult.elapsedMs,
    fallbackReason: runtimeResult.fallbackReason,
  };
  logAiExecution({
    clanId: input.clanId,
    uid: input.uid,
    authToken: input.authToken,
    feature: input.feature,
    locale: input.locale,
    traceId: input.traceId,
    result,
  });
  return result;
}

function normalizeAiFallbackReason(
  error: unknown,
): Exclude<AiFallbackReason, "disabled"> {
  if (error instanceof AiTimeoutError) {
    return "timeout";
  }
  if (
    error instanceof Error &&
    error.message.includes("did not match the expected schema")
  ) {
    return "invalid_output";
  }
  return "generation_error";
}

function logAiExecution(input: {
  clanId: string;
  uid: string;
  authToken: AuthToken;
  feature: string;
  locale: string;
  traceId: string;
  result: StructuredAiResult<unknown>;
}): void {
  const payload = {
    clanId: input.clanId,
    uid: input.uid,
    memberId: tokenMemberId(input.authToken),
    role: tokenPrimaryRole(input.authToken),
    feature: input.feature,
    locale: input.locale,
    traceId: input.traceId,
    elapsed_ms: input.result.elapsedMs,
    usedFallback: input.result.usedFallback,
    fallbackReason: input.result.fallbackReason,
    model: input.result.model,
  };

  if (
    input.result.usedFallback &&
    input.result.fallbackReason != null &&
    input.result.fallbackReason !== "disabled"
  ) {
    logWarn("AI callable completed with fallback", payload);
    return;
  }

  logInfo("AI callable completed", payload);
}

export function computeAiFeatureThrottleRemainingMs(input: {
  lastRequestedAtMs: number;
  nowMs: number;
  cooldownMs: number;
}): number {
  if (input.lastRequestedAtMs <= 0) {
    return 0;
  }
  return Math.max(
    0,
    input.cooldownMs - Math.max(0, input.nowMs - input.lastRequestedAtMs),
  );
}

async function enforceAiFeatureThrottle(input: {
  uid: string;
  clanId: string;
  feature: string;
  locale: string;
  traceId: string;
}): Promise<void> {
  const throttleRef = aiFeatureThrottleCollection.doc(
    `${input.uid}_${input.feature}`,
  );
  const nowMs = Date.now();
  const remainingMs = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(throttleRef);
    const state = asRecord(snapshot.data());
    const lastRequestedAtMs = readPositiveInt(state["lastRequestedAtMs"]);
    const pendingRemainingMs = computeAiFeatureThrottleRemainingMs({
      lastRequestedAtMs,
      nowMs,
      cooldownMs: AI_FEATURE_COOLDOWN_MS,
    });
    if (pendingRemainingMs > 0) {
      return pendingRemainingMs;
    }

    transaction.set(
      throttleRef,
      {
        id: throttleRef.id,
        uid: input.uid,
        clanId: input.clanId,
        feature: input.feature,
        lastRequestedAtMs: nowMs,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return 0;
  });

  if (remainingMs <= 0) {
    return;
  }

  logWarn("AI callable throttled", {
    clanId: input.clanId,
    uid: input.uid,
    feature: input.feature,
    locale: input.locale,
    traceId: input.traceId,
    remaining_ms: remainingMs,
  });
  throw new HttpsError(
    "resource-exhausted",
    localized(
      input.locale,
      `Bạn vừa dùng tính năng này. Hãy thử lại sau khoảng ${Math.ceil(
        remainingMs / 1000,
      )} giây.`,
      `You just used this feature. Try again in about ${Math.ceil(
        remainingMs / 1000,
      )} seconds.`,
    ),
  );
}

function getAiClient(): ReturnType<typeof genkit> | null {
  const apiKey = getAiApiKey();
  if (!AI_ASSIST_ENABLED || apiKey.length === 0) {
    return null;
  }

  if (cachedAiClient != null && cachedAiApiKey === apiKey) {
    return cachedAiClient;
  }

  cachedAiApiKey = apiKey;
  cachedAiClient = genkit({
    plugins: [googleAI({ apiKey })],
  });
  return cachedAiClient;
}

function buildSystemInstruction(locale: string): string {
  return localized(
    locale,
    "Trả lời bằng tiếng Việt tự nhiên, ngắn gọn, hữu ích cho người dùng Việt Nam. Không được bịa dữ kiện. Nếu dữ liệu chưa đủ, hãy nói rõ phần cần kiểm tra thêm.",
    "Reply in natural, concise English. Never invent facts. If the data is insufficient, clearly point out what should be checked next.",
  );
}

function buildProfileFallback(
  locale: string,
  draft: ProfileDraftInput,
): ProfileReview {
  const strengths: Array<string> = [];
  const missingImportant: Array<string> = [];
  const risks: Array<string> = [];
  const nextActions: Array<string> = [];

  if (countWords(draft.fullName) >= 2) {
    strengths.push(
      localized(
        locale,
        "Họ tên đã đủ rõ để người thân nhận ra.",
        "The full name is clear enough for relatives to recognize.",
      ),
    );
  } else {
    risks.push(
      localized(
        locale,
        "Họ tên hiện còn quá ngắn hoặc chưa đủ đầy đủ.",
        "The current full name looks too short or incomplete.",
      ),
    );
  }

  if (draft.hasPhone) {
    strengths.push(
      localized(
        locale,
        "Đã có số điện thoại để liên hệ trực tiếp.",
        "A phone number is available for direct contact.",
      ),
    );
  } else {
    missingImportant.push(
      localized(
        locale,
        "Nên thêm số điện thoại để gia đình dễ xác minh và liên hệ.",
        "Add a phone number so relatives can verify and contact this profile more easily.",
      ),
    );
  }

  if (draft.hasAddress) {
    strengths.push(
      localized(
        locale,
        "Địa chỉ đã có, giúp người thân nhận diện tốt hơn.",
        "An address is present, which makes this profile easier to recognize.",
      ),
    );
  } else {
    missingImportant.push(
      localized(
        locale,
        "Địa chỉ đang để trống, nên thêm nơi ở hiện tại hoặc quê quán.",
        "The address is empty, so consider adding the current residence or hometown.",
      ),
    );
  }

  if (draft.bioWordCount === 0) {
    missingImportant.push(
      localized(
        locale,
        "Nên thêm vài dòng giới thiệu ngắn để hồ sơ có ngữ cảnh hơn.",
        "Add a short bio so the profile has more context.",
      ),
    );
  } else if (draft.bioWordCount < 8) {
    risks.push(
      localized(
        locale,
        "Phần giới thiệu còn rất ngắn, khó tạo ngữ cảnh cho người xem.",
        "The bio is very short and may not provide enough context.",
      ),
    );
  }

  if (!draft.hasEmail && draft.socialLinkCount == 0) {
    missingImportant.push(
      localized(
        locale,
        "Chưa có email hoặc mạng xã hội để giữ liên lạc khi cần.",
        "There is no email or social link yet for follow-up contact.",
      ),
    );
  }

  if (draft.nickName.trim().length === 0) {
    nextActions.push(
      localized(
        locale,
        "Nếu trong nhà thường gọi bằng tên khác, hãy thêm biệt danh để dễ nhận ra hơn.",
        "If the family commonly uses another name, add a nickname for easier recognition.",
      ),
    );
  }
  if (draft.jobTitle.trim().length === 0) {
    nextActions.push(
      localized(
        locale,
        "Có thể thêm nghề nghiệp hoặc vai trò hiện tại để hồ sơ dễ phân biệt.",
        "Consider adding a job title or current role to distinguish this profile.",
      ),
    );
  }
  if (draft.bioWordCount === 0) {
    nextActions.push(
      localized(
        locale,
        "Viết 1-2 câu giới thiệu ngắn về nơi ở, công việc, hoặc cách kết nối với họ hàng.",
        "Write 1-2 short sentences about residence, work, or the family connection.",
      ),
    );
  }

  const completenessSignals = [
    draft.fullName,
    draft.hasPhone ? "phone" : "",
    draft.hasAddress ? "address" : "",
    draft.bioWordCount > 0 ? "bio" : "",
    draft.hasEmail ? "email" : "",
  ].filter((value) => value.length > 0).length;

  const summary =
    completenessSignals >= 4
      ? localized(
          locale,
          "Hồ sơ đã có nền khá tốt; chỉ cần bổ sung vài chi tiết để tăng độ tin cậy.",
          "This profile already has a solid foundation; only a few details are needed to improve trust.",
        )
      : localized(
          locale,
          "Hồ sơ dùng được nhưng còn thiếu vài dữ kiện quan trọng để người thân nhận ra nhanh.",
          "This profile is usable, but it still lacks a few important details for quick family recognition.",
        );

  return {
    summary,
    strengths: limitList(strengths, 3),
    missingImportant: limitList(missingImportant, 4),
    risks: limitList(risks, 3),
    nextActions: limitList(nextActions, 3),
  };
}

function buildEventCopyFallback(
  locale: string,
  draft: EventDraftInput,
): EventCopySuggestion {
  const startsAtLabel = formatIsoDateForLocale(locale, draft.startsAtIso);
  const locationLine = draft.locationName.trim();
  const hasLocationDetails =
    locationLine.length > 0 || draft.hasLocationAddress;

  let title = draft.title.trim();
  let description = draft.description.trim();
  const rationale: Array<string> = [];

  if (title.length === 0) {
    switch (draft.eventType) {
      case "death_anniversary":
        title = localized(
          locale,
          "Lễ tưởng niệm gia đình",
          "Family memorial service",
        );
        rationale.push(
          localized(
            locale,
            "Tiêu đề được giữ trang trọng vì đây là sự kiện tưởng niệm.",
            "The title is kept respectful because this is a memorial event.",
          ),
        );
        break;
      case "meeting":
        title = localized(locale, "Họp gia đình", "Family meeting");
        rationale.push(
          localized(
            locale,
            "Tiêu đề ưu tiên rõ mục đích để người xem hiểu ngay đây là buổi họp.",
            "The title prioritizes clarity so people immediately understand this is a meeting.",
          ),
        );
        break;
      case "birthday":
        title = localized(locale, "Mừng sinh nhật", "Birthday celebration");
        rationale.push(
          localized(
            locale,
            "Tiêu đề nhấn vào người được mừng để tăng cảm giác gần gũi.",
            "The title highlights the celebrated person to make it feel more personal.",
          ),
        );
        break;
      case "clan_gathering":
        title = localized(locale, "Gặp mặt dòng họ", "Clan gathering");
        rationale.push(
          localized(
            locale,
            "Tiêu đề ngắn gọn để phù hợp màn hình danh sách và thông báo.",
            "The title stays concise so it works well in lists and notifications.",
          ),
        );
        break;
      default:
        title = localized(locale, "Sự kiện gia đình", "Family event");
    }
  }

  if (description.length === 0) {
    if (draft.eventType == "death_anniversary") {
      description = localized(
        locale,
        `Kính mời con cháu sắp xếp thời gian tham dự đầy đủ. ${
          startsAtLabel.length === 0
            ? ""
            : `Thời gian dự kiến: ${startsAtLabel}. `
        }${
          !hasLocationDetails
            ? ""
            : locationLine.length > 0
              ? `Địa điểm: ${locationLine}.`
              : "Địa điểm đã được thêm trong chi tiết sự kiện."
        }`,
        `Family members are respectfully invited to attend. ${
          startsAtLabel.length === 0 ? "" : `Planned time: ${startsAtLabel}. `
        }${
          !hasLocationDetails
            ? ""
            : locationLine.length > 0
              ? `Location: ${locationLine}.`
              : "Location details are already included in the event."
        }`,
      ).trim();
    } else {
      description = localized(
        locale,
        `Mời mọi người theo dõi thời gian và sắp xếp tham gia. ${
          startsAtLabel.length === 0 ? "" : `Dự kiến: ${startsAtLabel}. `
        }${
          !hasLocationDetails
            ? ""
            : locationLine.length > 0
              ? `Địa điểm: ${locationLine}.`
              : "Địa điểm đã được thêm trong chi tiết sự kiện."
        }`,
        `Please review the time and plan to join. ${
          startsAtLabel.length === 0 ? "" : `Planned time: ${startsAtLabel}. `
        }${
          !hasLocationDetails
            ? ""
            : locationLine.length > 0
              ? `Location: ${locationLine}.`
              : "Location details are already included in the event."
        }`,
      ).trim();
    }
  }

  const reminders =
    draft.eventType == "death_anniversary"
      ? sanitizeReminderOffsets([10080, 1440, 120])
      : sanitizeReminderOffsets([1440, 120]);
  if (rationale.length < 3) {
    rationale.push(
      localized(
        locale,
        "Mốc nhắc lịch được giữ ít nhưng đủ để tránh quên việc chính.",
        "Reminder timing stays focused so the important follow-up is less likely to be missed.",
      ),
    );
  }

  return {
    title,
    description,
    recommendedReminderOffsetsMinutes: reminders,
    rationale: limitList(rationale, 3),
  };
}

function buildDuplicateExplanationFallback(
  locale: string,
  input: DuplicateExplanationInput,
): DuplicateExplanation {
  const topCandidate = [...input.candidates].sort(
    (left, right) => right.score - left.score,
  )[0];
  const topScore = topCandidate?.score ?? 0;
  const topSignals = input.candidates
    .slice(0, 3)
    .map((candidate) =>
      localized(
        locale,
        `${candidate.genealogyName} (${
          candidate.leaderName.length === 0
            ? "chưa rõ người đại diện"
            : candidate.leaderName
        }) có độ tương đồng ${candidate.score}%.`,
        `${candidate.genealogyName} (${
          candidate.leaderName.length === 0
            ? "representative unknown"
            : candidate.leaderName
        }) has ${candidate.score}% similarity.`,
      ),
    );

  const reviewChecklist = [
    localized(
      locale,
      "So lại tên gia phả, người đại diện và khu vực với ứng viên có điểm cao nhất.",
      "Compare the genealogy name, representative, and location with the top-scoring candidate.",
    ),
    localized(
      locale,
      "Kiểm tra xem đây là cùng một nhánh đã tồn tại hay là gia phả riêng thực sự.",
      "Check whether this is an existing branch of the same lineage or a truly separate tree.",
    ),
    localized(
      locale,
      "Nếu vẫn tạo mới, nên thêm mô tả khác biệt rõ trong phần giới thiệu.",
      "If you still create a new tree, add a clear differentiator in the description.",
    ),
  ];

  const recommendedAction =
    topScore >= 80
      ? "review_first"
      : topScore >= 60
        ? "uncertain"
        : "safe_to_override";

  const summary =
    recommendedAction == "review_first"
      ? localized(
          locale,
          "Nguy cơ trùng tương đối cao, nên rà lại trước khi tạo mới.",
          "Duplicate risk appears fairly high, so review first before creating a new tree.",
        )
      : recommendedAction == "uncertain"
        ? localized(
            locale,
            "Có vài tín hiệu giống nhau nhưng chưa đủ chắc chắn để kết luận.",
            "There are a few matching signals, but not enough to conclude with confidence.",
          )
        : localized(
            locale,
            "Các tín hiệu hiện tại chưa quá mạnh; có thể tiếp tục nếu bạn đã kiểm tra sơ bộ.",
            "Current signals are not especially strong; you can continue if you have already done a quick review.",
          );

  return {
    summary,
    topSignals: limitList(topSignals, 4),
    reviewChecklist: limitList(reviewChecklist, 4),
    recommendedAction,
  };
}

function buildAppAssistantFallback(
  locale: string,
  input: AppAssistantInput,
): AppAssistantReply {
  const normalizedQuestion = normalizeSearchText(input.question);
  const screenId = input.currentScreenId;

  if (
    containsAny(normalizedQuestion, [
      "thanh vien",
      "member",
      "ho so",
      "profile",
      "them nguoi",
      "add member",
    ])
  ) {
    return {
      answer: localized(
        locale,
        "Bạn nên bắt đầu từ khu vực gia phả hoặc hồ sơ để tạo đúng người và gắn đúng quan hệ.",
        "Start from the tree or profile area so you create the right person and attach the right relationships.",
      ),
      steps: [
        localized(
          locale,
          "Mở Tree để tạo thành viên mới hoặc kiểm tra người đó đã tồn tại chưa.",
          "Open Tree to create a new member or check whether that person already exists.",
        ),
        localized(
          locale,
          "Sau khi có người, cập nhật các chi tiết nhận diện như tên, số điện thoại, nơi ở hoặc ghi chú.",
          "Once the person exists, add recognizable details such as name, phone number, location, or notes.",
        ),
        localized(
          locale,
          "Nếu cần, nối tiếp các quan hệ cha mẹ, con cái hoặc vợ chồng để hồ sơ nằm đúng chỗ trong gia phả.",
          "If needed, connect parent, child, or spouse relationships so the profile sits in the right place in the tree.",
        ),
      ],
      quickReplies: buildDefaultQuickReplies(locale, "tree"),
      caution: localized(
        locale,
        "Nếu chưa chắc người này đã có trong hệ thống hay chưa, hãy tìm trước để tránh tạo trùng.",
        "If you are not sure whether this person already exists, search first to avoid duplicates.",
      ),
      suggestedDestination: "tree",
    };
  }

  if (
    containsAny(normalizedQuestion, [
      "gio ky",
      "ngay gio",
      "memorial",
      "event",
      "su kien",
      "calendar",
      "lich",
    ])
  ) {
    return {
      answer: localized(
        locale,
        "Những việc liên quan lịch, ngày giỗ và lời mời nên làm từ khu Events để app tự giữ mốc thời gian rõ ràng.",
        "Anything related to scheduling, memorial rituals, and invitations is best handled from Events so the timing stays organized.",
      ),
      steps: [
        localized(
          locale,
          "Mở Events rồi tạo sự kiện mới hoặc thêm mốc tưởng niệm nếu đây là ngày giỗ.",
          "Open Events, then create a new event or add a memorial ritual if this is a death anniversary.",
        ),
        localized(
          locale,
          "Điền thời gian, địa điểm và nội dung ngắn gọn để thông báo dễ hiểu với cả nhà.",
          "Fill in the time, place, and a concise description so the whole family can understand it quickly.",
        ),
        localized(
          locale,
          "Thiết lập các mốc nhắc lịch quan trọng như trước 1 ngày hoặc vài giờ.",
          "Add practical reminders such as one day before or a few hours before.",
        ),
      ],
      quickReplies: buildDefaultQuickReplies(locale, "events"),
      caution: localized(
        locale,
        "Với sự kiện tưởng niệm, nên kiểm tra lại ngày âm hoặc dương trước khi lưu chính thức.",
        "For memorial events, double-check whether the date should be lunar or solar before saving.",
      ),
      suggestedDestination: "events",
    };
  }

  if (
    containsAny(normalizedQuestion, [
      "goi",
      "plan",
      "premium",
      "paid",
      "billing",
      "quang cao",
      "ads",
    ])
  ) {
    return {
      answer: localized(
        locale,
        "Thông tin gói, quyền lợi và thanh toán nằm trong khu Billing.",
        "Plan details, entitlements, and payments live in Billing.",
      ),
      steps: [
        localized(
          locale,
          "Mở Billing để xem gói hiện tại và quyền lợi đang có.",
          "Open Billing to review the current plan and active entitlements.",
        ),
        localized(
          locale,
          "So gói đang dùng với số thành viên hoặc nhu cầu bỏ quảng cáo.",
          "Compare the current plan against your member count or ad-free needs.",
        ),
        localized(
          locale,
          "Nếu cần nâng cấp, làm ngay trong màn hình gói để entitlement cập nhật tập trung.",
          "If you need to upgrade, do it from the billing screen so entitlements update in one place.",
        ),
      ],
      quickReplies: buildDefaultQuickReplies(locale, "billing"),
      caution: localized(
        locale,
        "Sau khi thanh toán, nên tải lại màn hình gói để kiểm tra quyền lợi đã cập nhật.",
        "After payment, refresh the billing screen to confirm the entitlement updated.",
      ),
      suggestedDestination: "billing",
    };
  }

  if (
    containsAny(normalizedQuestion, [
      "ngon ngu",
      "language",
      "ho so",
      "profile",
      "cai dat",
      "settings",
    ])
  ) {
    return {
      answer: localized(
        locale,
        "Những việc như hoàn thiện hồ sơ, đổi ngôn ngữ và quản lý cài đặt nên làm từ Profile.",
        "Tasks like completing the profile, changing language, and managing settings belong in Profile.",
      ),
      steps: [
        localized(
          locale,
          "Mở Profile để xem và chỉnh các thông tin nhận diện của tài khoản hoặc thành viên.",
          "Open Profile to view and edit identity details for the account or member.",
        ),
        localized(
          locale,
          "Vào phần cài đặt nếu bạn cần đổi ngôn ngữ hoặc xem lại thông báo.",
          "Open settings from Profile if you need to change language or review notifications.",
        ),
        localized(
          locale,
          "Bổ sung các mục còn trống như liên hệ hoặc mô tả ngắn để hồ sơ rõ hơn.",
          "Fill in missing details such as contact links or a short bio to make the profile clearer.",
        ),
      ],
      quickReplies: buildDefaultQuickReplies(locale, "profile"),
      caution: localized(
        locale,
        "Nếu hồ sơ là hồ sơ chung của gia đình, nên kiểm tra kỹ trước khi đổi các thông tin nhận diện chính.",
        "If this is a shared family profile, review the main identity fields carefully before changing them.",
      ),
      suggestedDestination: "profile",
    };
  }

  return {
    answer: localized(
      locale,
      "Mình có thể giúp bạn đi đúng chỗ trong BeFam và rút gọn các bước thao tác cần làm.",
      "I can help you move to the right BeFam area and shorten the steps you need to take.",
    ),
    steps: defaultAssistantSteps(locale, screenId),
    quickReplies: buildDefaultQuickReplies(locale, screenId),
    caution: localized(
      locale,
      "Nếu bạn nói rõ mục tiêu hơn, mình sẽ chỉ đúng màn và đúng thứ tự thao tác.",
      "If you tell me the goal more clearly, I can point you to the exact screen and action order.",
    ),
    suggestedDestination: screenId,
  };
}

export function readProfileDraftInput(value: unknown): ProfileDraftInput {
  const data = asRecord(value);
  return {
    fullName: requireNonEmptyString(data, "fullName"),
    nickName: optionalString(data, "nickName"),
    jobTitle: optionalString(data, "jobTitle"),
    hasPhone: data["hasPhone"] === true,
    hasEmail: data["hasEmail"] === true,
    hasAddress: data["hasAddress"] === true,
    bioWordCount: readPositiveInt(data["bioWordCount"]),
    socialLinkCount: Math.min(6, readPositiveInt(data["socialLinkCount"])),
  };
}

export function readEventDraftInput(value: unknown): EventDraftInput {
  const data = asRecord(value);
  return {
    clanId: requireNonEmptyString(data, "clanId"),
    eventType: requireNonEmptyString(data, "eventType"),
    title: optionalString(data, "title"),
    description: optionalString(data, "description"),
    locationName: optionalString(data, "locationName"),
    hasLocationAddress: data["hasLocationAddress"] === true,
    startsAtIso: optionalString(data, "startsAtIso"),
    timezone: optionalString(data, "timezone"),
    isRecurring: data["isRecurring"] == true,
  };
}

function readDuplicateExplanationInput(
  value: unknown,
): DuplicateExplanationInput {
  const data = asRecord(value);
  const rawCandidates = Array.isArray(data["candidates"])
    ? data["candidates"]
    : [];
  const candidates = rawCandidates
    .map((entry) => asRecord(entry))
    .map((candidate) => ({
      clanId: optionalString(candidate, "clanId").slice(0, 80),
      genealogyName: optionalString(candidate, "genealogyName").slice(0, 160),
      leaderName: optionalString(candidate, "leaderName").slice(0, 120),
      provinceCity: optionalString(candidate, "provinceCity").slice(0, 120),
      score: toNumber(candidate["score"]),
      summary: optionalString(candidate, "summary").slice(0, 240),
      memberCount: toNullableInt(candidate["memberCount"]),
    }))
    .filter((candidate) => candidate.genealogyName.length > 0)
    .slice(0, 8);

  if (candidates.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "At least one duplicate candidate is required.",
    );
  }

  return {
    clanId: requireNonEmptyString(data, "clanId"),
    genealogyName: requireNonEmptyString(data, "genealogyName").slice(0, 160),
    founderName: optionalString(data, "founderName").slice(0, 120),
    countryCode: optionalString(data, "countryCode").slice(0, 12),
    description: optionalString(data, "description").slice(0, 600),
    candidates,
  };
}

function resolveClanId(token: AuthToken, preferredClanId: string): string {
  if (preferredClanId.length > 0) {
    return preferredClanId;
  }
  const clanId = tokenClanIds(token)[0];
  if (clanId == null) {
    throw new HttpsError(
      "failed-precondition",
      "This session is not linked to a clan.",
    );
  }
  return clanId;
}

function normalizeLocale(value: string): string {
  const normalized = value.trim().toLowerCase();
  if (normalized.startsWith("en")) {
    return "en";
  }
  return "vi";
}

function localized(locale: string, vi: string, en: string): string {
  return locale == "en" ? en : vi;
}

function optionalString(
  source: Record<string, unknown> | unknown,
  key: string,
): string {
  if (source == null || typeof source !== "object") {
    return "";
  }
  return stringOrNull((source as Record<string, unknown>)[key]) ?? "";
}

function requireNonEmptyString(
  source: Record<string, unknown>,
  key: string,
): string {
  const value = optionalString(source, key);
  if (value.length == 0) {
    throw new HttpsError("invalid-argument", `Missing required field: ${key}`);
  }
  return value;
}

function asRecord(value: unknown): Record<string, unknown> {
  if (value != null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function readAppAssistantInput(value: unknown): AppAssistantInput {
  const data = asRecord(value);
  const clanId = requireNonEmptyString(data, "clanId");
  const question = requireNonEmptyString(data, "question").slice(0, 900);
  const currentScreenId = normalizeScreenId(
    optionalString(data, "currentScreenId"),
  );
  const currentScreenTitle = optionalString(data, "currentScreenTitle").slice(
    0,
    120,
  );
  const activeClanName = optionalString(data, "activeClanName").slice(0, 120);
  const rawHistory = Array.isArray(data["history"]) ? data["history"] : [];
  const history = rawHistory
    .map((entry) => asRecord(entry))
    .map((entry) => ({
      role: normalizeAssistantHistoryRole(optionalString(entry, "role")),
      text: optionalString(entry, "text").slice(0, 600),
    }))
    .filter((entry) => entry.text.length > 0)
    .slice(-8);

  return {
    clanId,
    currentScreenId,
    currentScreenTitle:
      currentScreenTitle.length > 0 ? currentScreenTitle : currentScreenId,
    activeClanName,
    question,
    history,
  };
}

function normalizeScreenId(
  value: string,
): AppAssistantInput["currentScreenId"] {
  switch (value.trim().toLowerCase()) {
    case "tree":
      return "tree";
    case "events":
      return "events";
    case "billing":
      return "billing";
    case "profile":
      return "profile";
    default:
      return "home";
  }
}

function normalizeAssistantHistoryRole(
  value: string,
): AppAssistantHistoryMessage["role"] {
  return value.trim().toLowerCase() == "assistant" ? "assistant" : "user";
}

function buildDefaultQuickReplies(
  locale: string,
  screenId: AppAssistantInput["currentScreenId"],
): Array<string> {
  switch (screenId) {
    case "tree":
      return [
        localized(locale, "Cách thêm thành viên?", "How do I add a member?"),
        localized(
          locale,
          "Cách nối quan hệ?",
          "How do I connect relationships?",
        ),
        localized(
          locale,
          "Làm sao tránh tạo trùng?",
          "How do I avoid duplicates?",
        ),
      ];
    case "events":
      return [
        localized(locale, "Tạo ngày giỗ", "Create a memorial event"),
        localized(locale, "Đặt nhắc lịch", "Set reminders"),
        localized(
          locale,
          "Dùng lịch âm hay dương?",
          "Use lunar or solar dates?",
        ),
      ];
    case "billing":
      return [
        localized(locale, "So sánh gói", "Compare plans"),
        localized(locale, "Cập nhật quyền lợi", "Refresh entitlements"),
        localized(locale, "Bỏ quảng cáo", "Remove ads"),
      ];
    case "profile":
      return [
        localized(locale, "Hoàn thiện hồ sơ", "Complete the profile"),
        localized(locale, "Đổi ngôn ngữ", "Change language"),
        localized(locale, "Quản lý thông báo", "Manage notifications"),
      ];
    default:
      return [
        localized(locale, "Bắt đầu từ đâu?", "Where should I start?"),
        localized(locale, "Mời người thân", "Invite relatives"),
        localized(locale, "Tạo sự kiện", "Create an event"),
      ];
  }
}

function defaultAssistantSteps(
  locale: string,
  screenId: AppAssistantInput["currentScreenId"],
): Array<string> {
  switch (screenId) {
    case "tree":
      return [
        localized(
          locale,
          "Kiểm tra người hoặc nhánh bạn muốn thao tác đã có trong gia phả chưa.",
          "Check whether the person or branch already exists in the tree.",
        ),
        localized(
          locale,
          "Thêm hoặc chỉnh hồ sơ trước, rồi mới nối quan hệ để tránh sai vị trí.",
          "Add or edit the profile first, then connect relationships to avoid placing it incorrectly.",
        ),
        localized(
          locale,
          "Xem lại các cạnh quan hệ sau khi lưu để xác nhận cây hiển thị đúng.",
          "Review the relationship edges after saving to confirm the tree renders correctly.",
        ),
      ];
    case "events":
      return [
        localized(
          locale,
          "Chọn đúng loại sự kiện hoặc tưởng niệm trong Events.",
          "Choose the correct event or memorial type in Events.",
        ),
        localized(
          locale,
          "Điền thời gian, địa điểm và vài dòng mô tả ngắn.",
          "Fill in the time, location, and a short description.",
        ),
        localized(
          locale,
          "Thêm mốc nhắc thực dụng để cả nhà không bỏ lỡ.",
          "Add practical reminders so the family does not miss it.",
        ),
      ];
    case "billing":
      return [
        localized(
          locale,
          "Kiểm tra gói hiện tại và giới hạn đang áp dụng.",
          "Review the current plan and the active limits.",
        ),
        localized(
          locale,
          "So nhu cầu sử dụng với gói phù hợp hơn nếu cần.",
          "Compare your usage needs against the better-fitting plan if needed.",
        ),
        localized(
          locale,
          "Sau khi đổi gói hoặc thanh toán, tải lại để xem entitlement mới.",
          "After upgrading or paying, refresh to see the updated entitlement.",
        ),
      ];
    case "profile":
      return [
        localized(
          locale,
          "Mở hồ sơ và bổ sung các thông tin nhận diện còn thiếu.",
          "Open the profile and fill in any missing identity details.",
        ),
        localized(
          locale,
          "Vào cài đặt nếu bạn cần đổi ngôn ngữ hoặc quyền riêng tư.",
          "Go to settings if you need to change language or privacy settings.",
        ),
        localized(
          locale,
          "Lưu xong thì kiểm tra lại hồ sơ hiển thị với người thân có đủ rõ chưa.",
          "After saving, check whether the profile now looks clear enough to relatives.",
        ),
      ];
    default:
      return [
        localized(
          locale,
          "Bắt đầu ở Home để xem lối tắt và những việc quan trọng nhất.",
          "Start in Home to review shortcuts and the most important next actions.",
        ),
        localized(
          locale,
          "Chuyển sang Tree khi bạn cần làm việc với gia phả hoặc thành viên.",
          "Move to Tree when you need to work with genealogy or members.",
        ),
        localized(
          locale,
          "Chuyển sang Events hoặc Billing khi mục tiêu liên quan lịch hoặc quyền lợi.",
          "Move to Events or Billing when the goal is about scheduling or entitlements.",
        ),
      ];
  }
}

function normalizeSearchText(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "");
}

function containsAny(haystack: string, needles: Array<string>): boolean {
  return needles.some((needle) => haystack.includes(needle));
}

async function ensurePremiumAssistantAccess(input: {
  uid: string;
  clanId: string;
  locale: string;
}): Promise<void> {
  const ownerUid = await resolveClanOwnerUid(input.clanId);
  const subscription = await loadSubscription({
    clanId: input.clanId,
    ownerUid,
  });
  const entitlement =
    subscription == null
      ? null
      : buildEntitlementFromSubscription(subscription);
  if (entitlement?.hasPremiumAccess != true) {
    throw new HttpsError(
      "permission-denied",
      localized(
        input.locale,
        "Trợ lý AI chỉ khả dụng cho các gói BeFam trả phí.",
        "The AI assistant is available on paid BeFam plans only.",
      ),
    );
  }
}

async function resolveClanOwnerUid(clanId: string): Promise<string> {
  const snapshot = await clansCollection.doc(clanId).get();
  if (!snapshot.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Clan billing scope is not configured yet.",
    );
  }
  const ownerUid = stringOrNull(snapshot.data()?.ownerUid) ?? "";
  if (ownerUid.length === 0) {
    throw new HttpsError("failed-precondition", "Clan owner is missing.");
  }
  return ownerUid;
}

function limitList(values: Array<string>, limit: number): Array<string> {
  const unique = values
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
  return [...new Set(unique)].slice(0, limit);
}

function sanitizeReminderOffsets(values: Array<number>): Array<number> {
  return [
    ...new Set(
      values
        .filter((value) => Number.isFinite(value))
        .map((value) => Math.round(value))
        .filter((value) => value > 0),
    ),
  ]
    .sort((left, right) => right - left)
    .slice(0, 4);
}

function countWords(value: string): number {
  return value
    .trim()
    .split(/\s+/)
    .filter((token) => token.length > 0).length;
}

function toNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number.parseFloat(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return 0;
}

function readPositiveInt(value: unknown): number {
  const parsed = toNumber(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return 0;
  }
  return Math.round(parsed);
}

function toNullableInt(value: unknown): number | null {
  const parsed = readPositiveInt(value);
  if (parsed <= 0) {
    return null;
  }
  return parsed;
}

function formatIsoDateForLocale(locale: string, value: string): string {
  if (value.trim().length === 0) {
    return "";
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return "";
  }
  try {
    return new Intl.DateTimeFormat(locale == "en" ? "en-US" : "vi-VN", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    }).format(parsed);
  } catch {
    return parsed.toISOString();
  }
}
