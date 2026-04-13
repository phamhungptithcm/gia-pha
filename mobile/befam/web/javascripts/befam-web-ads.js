const BEFAM_WEB_AD_POLICY = Object.freeze({
  minSessionAgeSec: 75,
  minActions: 3,
  minIntervalSec: 120,
  maxAdsPerSession: 1,
  maxAdsPerDay: 3,
  newUserGraceSessions: 2,
  newUserGraceDays: 1,
  returningUserMinIntervalSec: 180,
  lowEngagementDailyCap: 1,
  churnRiskShortSessions7d: 3,
  churnRiskFrustrationSignals7d: 2,
  frustrationExitWindowSec: 20,
  shortSessionWindowSec: 45,
  docsMinTextLength: 1200,
});

const BEFAM_WEB_AD_ALLOWLIST = new Set([
  "landing_home",
  "landing_about",
  "landing_info",
  "docs_article",
]);

const BEFAM_WEB_AD_STORAGE_NAMESPACE = ["befam", "webAds"].join(".");
const BEFAM_WEB_AD_PERSISTED_STORAGE_ID =
  createBefamWebAdsStorageId("persisted");
const BEFAM_WEB_AD_SESSION_STORAGE_ID = createBefamWebAdsStorageId("session");
const BEFAM_WEB_AD_REFRESH_MS = 5000;
const BEFAM_WEB_AD_LOOKBACK_7D_MS = 7 * 24 * 60 * 60 * 1000;
const BEFAM_WEB_AD_LOOKBACK_24H_MS = 24 * 60 * 60 * 1000;

const befamWebAdsState = {
  bootstrapped: false,
  listenersInstalled: false,
  mutationObserver: null,
  refreshTimerId: 0,
  lastInteractionAt: 0,
  persistent: null,
  session: null,
  slots: new Set(),
};

bootstrapBefamWebAds();

function bootstrapBefamWebAds() {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initializeBefamWebAds, {
      once: true,
    });
  } else {
    initializeBefamWebAds();
  }

  if (typeof document$ !== "undefined" && document$?.subscribe) {
    document$.subscribe(() => {
      window.requestAnimationFrame(() => {
        initializeBefamWebAds();
      });
    });
  }
}

function createBefamWebAdsStorageId(scope) {
  return `${BEFAM_WEB_AD_STORAGE_NAMESPACE}.${scope}.v1`;
}

function initializeBefamWebAds() {
  if (!befamWebAdsState.bootstrapped) {
    befamWebAdsState.bootstrapped = true;
    befamWebAdsState.persistent = readPersistedState();
    befamWebAdsState.session = readSessionState();
    startSessionIfNeeded();
    ensureSharedStyles();
    installEngagementListeners();
    installLifecycleListeners();
    installMutationObserver();
    scheduleRefreshLoop();
  }

  ensureDocsArticleAdSlot();
  scanAdSlots();
  refreshVisibleSlots();
}

function ensureSharedStyles() {
  if (document.getElementById("befam-web-ads-style")) {
    return;
  }

  const style = document.createElement("style");
  style.id = "befam-web-ads-style";
  style.textContent = `
    .befam-web-ad-slot {
      width: 100%;
      display: block;
    }

    .befam-web-ad-shell {
      min-height: inherit;
      padding: 14px 16px 16px;
      border-radius: 24px;
      border: 1px solid rgba(31, 78, 95, 0.12);
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.92), rgba(248, 250, 252, 0.92));
      box-shadow: 0 18px 40px rgba(15, 23, 42, 0.06);
      overflow: hidden;
      box-sizing: border-box;
    }

    .befam-web-ad-label {
      margin-bottom: 10px;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: rgba(71, 85, 105, 0.88);
    }

    .befam-web-ad-body {
      min-height: calc(100% - 24px);
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 18px;
      background: rgba(241, 245, 249, 0.72);
    }

    .befam-web-ad-body > ins.adsbygoogle {
      width: 100%;
      min-height: inherit;
    }
  `;
  document.head.appendChild(style);
}

function installEngagementListeners() {
  if (befamWebAdsState.listenersInstalled) {
    return;
  }
  befamWebAdsState.listenersInstalled = true;

  const interactionHandler = () => {
    noteInteraction();
  };

  window.addEventListener("pointerdown", interactionHandler, {
    passive: true,
  });
  window.addEventListener("click", interactionHandler, { passive: true });
  window.addEventListener("keydown", interactionHandler);
  window.addEventListener("wheel", interactionHandler, { passive: true });
}

function installLifecycleListeners() {
  window.addEventListener("pagehide", () => {
    persistSessionEnd();
  });

  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") {
      refreshVisibleSlots();
    }
  });
}

function installMutationObserver() {
  if (befamWebAdsState.mutationObserver != null) {
    return;
  }

  befamWebAdsState.mutationObserver = new MutationObserver(() => {
    scanAdSlots();
    refreshVisibleSlots();
  });
  befamWebAdsState.mutationObserver.observe(document.body, {
    childList: true,
    subtree: true,
  });
}

function scheduleRefreshLoop() {
  if (befamWebAdsState.refreshTimerId !== 0) {
    return;
  }

  befamWebAdsState.refreshTimerId = window.setInterval(() => {
    refreshVisibleSlots();
  }, BEFAM_WEB_AD_REFRESH_MS);
}

function noteInteraction() {
  const now = Date.now();
  if (now - befamWebAdsState.lastInteractionAt < 1200) {
    return;
  }

  befamWebAdsState.lastInteractionAt = now;
  befamWebAdsState.session.interactions += 1;
  persistSessionState();
  refreshVisibleSlots();
}

function startSessionIfNeeded() {
  if (Number.isFinite(befamWebAdsState.session.startedAt)) {
    return;
  }

  const now = Date.now();
  befamWebAdsState.session = {
    startedAt: now,
    interactions: 0,
    adsThisSession: 0,
    lastAdAt: 0,
  };

  const persistent = befamWebAdsState.persistent;
  if (persistent.firstSeenAt <= 0) {
    persistent.firstSeenAt = now;
  }

  persistent.totalSessions += 1;
  persistent.recentSessionStarts = trimTimestamps(
    [...persistent.recentSessionStarts, now],
    BEFAM_WEB_AD_LOOKBACK_7D_MS,
  );
  persistState();
}

function readPersistedState() {
  const raw = readJsonStorage(
    window.localStorage,
    BEFAM_WEB_AD_PERSISTED_STORAGE_ID,
  );
  return {
    firstSeenAt: toFiniteNumber(raw?.firstSeenAt, 0),
    totalSessions: toFiniteNumber(raw?.totalSessions, 0),
    recentSessionStarts: trimTimestamps(raw?.recentSessionStarts ?? [], BEFAM_WEB_AD_LOOKBACK_7D_MS),
    recentShortSessions: trimTimestamps(raw?.recentShortSessions ?? [], BEFAM_WEB_AD_LOOKBACK_7D_MS),
    adShows: trimTimestamps(raw?.adShows ?? [], BEFAM_WEB_AD_LOOKBACK_24H_MS),
    frustrationSignals: trimTimestamps(raw?.frustrationSignals ?? [], BEFAM_WEB_AD_LOOKBACK_7D_MS),
    lastSessionEndedAt: toFiniteNumber(raw?.lastSessionEndedAt, 0),
  };
}

function readSessionState() {
  const raw = readJsonStorage(
    window.sessionStorage,
    BEFAM_WEB_AD_SESSION_STORAGE_ID,
  );
  return {
    startedAt: toFiniteNumber(raw?.startedAt, Number.NaN),
    interactions: toFiniteNumber(raw?.interactions, 0),
    adsThisSession: toFiniteNumber(raw?.adsThisSession, 0),
    lastAdAt: toFiniteNumber(raw?.lastAdAt, 0),
  };
}

function persistState() {
  persistPersistentState();
  persistSessionState();
}

function persistPersistentState() {
  writeJsonStorage(
    window.localStorage,
    BEFAM_WEB_AD_PERSISTED_STORAGE_ID,
    befamWebAdsState.persistent,
  );
}

function persistSessionState() {
  writeJsonStorage(
    window.sessionStorage,
    BEFAM_WEB_AD_SESSION_STORAGE_ID,
    befamWebAdsState.session,
  );
}

function persistSessionEnd() {
  const session = befamWebAdsState.session;
  if (!Number.isFinite(session.startedAt)) {
    return;
  }

  const now = Date.now();
  const durationSec = Math.max(0, Math.round((now - session.startedAt) / 1000));
  const persistent = befamWebAdsState.persistent;

  if (durationSec <= BEFAM_WEB_AD_POLICY.shortSessionWindowSec) {
    persistent.recentShortSessions = trimTimestamps(
      [...persistent.recentShortSessions, now],
      BEFAM_WEB_AD_LOOKBACK_7D_MS,
    );
  }

  if (
    session.lastAdAt > 0 &&
    now - session.lastAdAt <=
      BEFAM_WEB_AD_POLICY.frustrationExitWindowSec * 1000
  ) {
    persistent.frustrationSignals = trimTimestamps(
      [...persistent.frustrationSignals, now],
      BEFAM_WEB_AD_LOOKBACK_7D_MS,
    );
  }

  persistent.lastSessionEndedAt = now;
  persistPersistentState();
}

function scanAdSlots() {
  document.querySelectorAll("[data-befam-ad-slot]").forEach((slot) => {
    if (!(slot instanceof HTMLElement)) {
      return;
    }

    prepareSlot(slot);
    befamWebAdsState.slots.add(slot);
  });
}

function prepareSlot(slot) {
  if (slot.dataset.befamPrepared === "1") {
    return;
  }

  slot.dataset.befamPrepared = "1";
  slot.classList.add("befam-web-ad-slot");
  slot.style.minHeight = `${toFiniteNumber(slot.dataset.befamMinHeight, 236)}px`;
  ensureAdShell(slot);
}

function ensureAdShell(slot) {
  if (slot.querySelector(".befam-web-ad-shell")) {
    return;
  }

  slot.replaceChildren();

  const shell = document.createElement("div");
  shell.className = "befam-web-ad-shell";

  const label = document.createElement("div");
  label.className = "befam-web-ad-label";
  label.textContent = getAdLabel();

  const body = document.createElement("div");
  body.className = "befam-web-ad-body";

  shell.append(label, body);
  slot.appendChild(shell);
}

function refreshVisibleSlots() {
  for (const slot of [...befamWebAdsState.slots]) {
    if (!(slot instanceof HTMLElement) || !slot.isConnected) {
      befamWebAdsState.slots.delete(slot);
      continue;
    }

    if (slot.dataset.befamRendered === "1" || slot.dataset.befamRequested === "1") {
      continue;
    }

    if (!isSlotNearViewport(slot)) {
      continue;
    }

    if (!canRenderSlot(slot)) {
      continue;
    }

    void renderSlot(slot);
  }
}

function canRenderSlot(slot) {
  const pageType = `${slot.dataset.befamPageType ?? ""}`.trim();
  const slotId = `${slot.dataset.befamSlotId ?? ""}`.trim();
  const client = `${slot.dataset.befamAdClient ?? ""}`.trim();
  const breakpoint = `${slot.dataset.befamBreakpoint ?? ""}`.trim();

  if (!pageType || !slotId || !client) {
    return false;
  }
  if (!BEFAM_WEB_AD_ALLOWLIST.has(pageType)) {
    return false;
  }
  if (breakpoint !== "content_unit_end") {
    return false;
  }

  const now = Date.now();
  const persistent = befamWebAdsState.persistent;
  const session = befamWebAdsState.session;
  const segment = inferSegment(now);

  if (segment === "newUser" || segment === "churnRisk") {
    return false;
  }

  const sessionAgeSec = Math.round((now - session.startedAt) / 1000);
  if (sessionAgeSec < BEFAM_WEB_AD_POLICY.minSessionAgeSec) {
    return false;
  }

  const effectiveActions = session.interactions + 3;
  if (effectiveActions < BEFAM_WEB_AD_POLICY.minActions) {
    return false;
  }

  if (session.adsThisSession >= BEFAM_WEB_AD_POLICY.maxAdsPerSession) {
    return false;
  }

  const adShowsLast24h = trimTimestamps(
    persistent.adShows,
    BEFAM_WEB_AD_LOOKBACK_24H_MS,
  ).length;

  let minIntervalSec = BEFAM_WEB_AD_POLICY.minIntervalSec;
  let maxAdsPerDay = BEFAM_WEB_AD_POLICY.maxAdsPerDay;

  if (segment === "returningUser") {
    minIntervalSec = Math.max(
      minIntervalSec,
      BEFAM_WEB_AD_POLICY.returningUserMinIntervalSec,
    );
  }

  if (segment === "lowEngagement") {
    maxAdsPerDay = Math.min(
      maxAdsPerDay,
      BEFAM_WEB_AD_POLICY.lowEngagementDailyCap,
    );
  }

  if (adShowsLast24h >= maxAdsPerDay) {
    return false;
  }

  const lastAdAt = Math.max(session.lastAdAt, latestTimestamp(persistent.adShows));
  if (lastAdAt > 0 && now - lastAdAt < minIntervalSec * 1000) {
    return false;
  }

  return true;
}

async function renderSlot(slot) {
  const client = `${slot.dataset.befamAdClient ?? ""}`.trim();
  const slotId = `${slot.dataset.befamSlotId ?? ""}`.trim();
  const body = slot.querySelector(".befam-web-ad-body");

  if (!client || !slotId || !(body instanceof HTMLElement)) {
    return;
  }

  slot.dataset.befamRequested = "1";
  body.replaceChildren();

  const adNode = document.createElement("ins");
  adNode.className = "adsbygoogle";
  adNode.style.display = "block";
  adNode.style.width = "100%";
  adNode.style.minHeight = `${toFiniteNumber(slot.dataset.befamMinHeight, 236) - 40}px`;
  adNode.setAttribute("data-ad-client", client);
  adNode.setAttribute("data-ad-slot", slotId);
  adNode.setAttribute("data-ad-format", "auto");
  adNode.setAttribute("data-full-width-responsive", "true");
  body.appendChild(adNode);

  try {
    await ensureAdSenseScript(client);
    (window.adsbygoogle = window.adsbygoogle || []).push({});

    slot.dataset.befamRendered = "1";
    recordAdShown();
  } catch {
    slot.dataset.befamRequested = "0";
    body.replaceChildren();
  }
}

function recordAdShown() {
  const now = Date.now();
  const persistent = befamWebAdsState.persistent;
  const session = befamWebAdsState.session;

  session.adsThisSession += 1;
  session.lastAdAt = now;
  persistent.adShows = trimTimestamps(
    [...persistent.adShows, now],
    BEFAM_WEB_AD_LOOKBACK_24H_MS,
  );
  persistState();
}

function inferSegment(now) {
  const persistent = befamWebAdsState.persistent;
  const daysSinceFirstSeen =
    persistent.firstSeenAt > 0
      ? Math.floor((now - persistent.firstSeenAt) / (24 * 60 * 60 * 1000))
      : 0;

  if (
    daysSinceFirstSeen < BEFAM_WEB_AD_POLICY.newUserGraceDays ||
    persistent.totalSessions <= BEFAM_WEB_AD_POLICY.newUserGraceSessions
  ) {
    return "newUser";
  }

  const recentSessions7d = trimTimestamps(
    persistent.recentSessionStarts,
    BEFAM_WEB_AD_LOOKBACK_7D_MS,
  ).length;
  const recentShortSessions7d = trimTimestamps(
    persistent.recentShortSessions,
    BEFAM_WEB_AD_LOOKBACK_7D_MS,
  ).length;
  const frustrationSignals7d = trimTimestamps(
    persistent.frustrationSignals,
    BEFAM_WEB_AD_LOOKBACK_7D_MS,
  ).length;

  if (
    frustrationSignals7d >= BEFAM_WEB_AD_POLICY.churnRiskFrustrationSignals7d ||
    recentShortSessions7d >= BEFAM_WEB_AD_POLICY.churnRiskShortSessions7d
  ) {
    return "churnRisk";
  }

  if (
    persistent.lastSessionEndedAt > 0 &&
    now - persistent.lastSessionEndedAt >= 3 * 24 * 60 * 60 * 1000
  ) {
    return "returningUser";
  }

  if (recentSessions7d <= 2 || recentShortSessions7d >= 2) {
    return "lowEngagement";
  }

  return "standard";
}

function ensureDocsArticleAdSlot() {
  const config = window.BEFAM_DOCS_ADS_CONFIG;
  if (
    !config ||
    config.enabled !== true ||
    typeof config.docsArticleEndSlotId !== "string" ||
    config.docsArticleEndSlotId.trim() === ""
  ) {
    return;
  }

  const article = document.querySelector(".md-content__inner > article");
  if (!(article instanceof HTMLElement)) {
    return;
  }

  const path = normalizePath(window.location.pathname);
  if (path === "/" || path === "/en/" || path === "/vi/") {
    return;
  }

  const textLength = article.textContent?.replace(/\s+/g, " ").trim().length ?? 0;
  if (textLength < BEFAM_WEB_AD_POLICY.docsMinTextLength) {
    return;
  }

  const existing = article.querySelector("[data-befam-docs-ad-wrapper='1']");
  if (existing) {
    return;
  }

  const wrapper = document.createElement("div");
  wrapper.setAttribute("data-befam-docs-ad-wrapper", "1");
  wrapper.setAttribute("data-befam-ad-slot", "docs_article_end");
  wrapper.setAttribute("data-befam-ad-client", `${config.adClient ?? ""}`.trim());
  wrapper.setAttribute(
    "data-befam-slot-id",
    `${config.docsArticleEndSlotId ?? ""}`.trim(),
  );
  wrapper.setAttribute("data-befam-page-type", "docs_article");
  wrapper.setAttribute("data-befam-breakpoint", "content_unit_end");
  wrapper.setAttribute("data-befam-min-height", "240");
  wrapper.style.marginTop = "1.4rem";

  article.appendChild(wrapper);
}

function ensureAdSenseScript(client) {
  if (window.befamAdSenseScriptPromise) {
    return window.befamAdSenseScriptPromise;
  }

  window.befamAdSenseScriptPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector(
      "script[data-befam-adsense-script='1']",
    );
    if (existing) {
      resolve();
      return;
    }

    const script = document.createElement("script");
    script.async = true;
    script.crossOrigin = "anonymous";
    script.dataset.befamAdsenseScript = "1";
    script.src =
      "https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=" +
      encodeURIComponent(client);
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("adsense_load_failed"));
    document.head.appendChild(script);
  });

  return window.befamAdSenseScriptPromise;
}

function isSlotNearViewport(slot) {
  const rect = slot.getBoundingClientRect();
  const viewportHeight =
    window.innerHeight || document.documentElement.clientHeight || 0;

  return rect.top <= viewportHeight * 1.15 && rect.bottom >= 0;
}

function normalizePath(pathname) {
  const normalized = `${pathname || "/"}`.replace(/\/{2,}/g, "/");
  if (normalized === "/") {
    return normalized;
  }
  return normalized.endsWith("/") ? normalized : `${normalized}/`;
}

function getAdLabel() {
  const path = normalizePath(window.location.pathname);
  return path.startsWith("/en/") ? "Sponsored" : "Quảng cáo";
}

function trimTimestamps(values, lookbackMs) {
  const now = Date.now();
  return (Array.isArray(values) ? values : [])
    .map((value) => Number(value))
    .filter((value) => Number.isFinite(value) && now - value <= lookbackMs)
    .sort((left, right) => left - right);
}

function latestTimestamp(values) {
  const normalized = trimTimestamps(values, BEFAM_WEB_AD_LOOKBACK_24H_MS);
  return normalized.length === 0 ? 0 : normalized[normalized.length - 1];
}

function toFiniteNumber(value, fallback) {
  const normalized = Number(value);
  return Number.isFinite(normalized) ? normalized : fallback;
}

function readJsonStorage(storage, key) {
  try {
    const raw = storage.getItem(key);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function writeJsonStorage(storage, key, value) {
  try {
    storage.setItem(key, JSON.stringify(value));
  } catch {
    // Ignore storage write failures.
  }
}
