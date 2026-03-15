const RELEASES_API_URL =
  "https://api.github.com/repos/phamhungptithcm/gia-pha/releases/latest";
const RELEASES_PAGE_URL = "https://github.com/phamhungptithcm/gia-pha/releases";
const RELEASE_CACHE_KEY = "befam.docs.latestRelease";
const RELEASE_CACHE_TTL_MS = 5 * 60 * 1000;

document$.subscribe(() => {
  void syncReleaseMetadata();
});

async function syncReleaseMetadata() {
  try {
    const release = await loadLatestRelease();
    if (!release || typeof release !== "object") {
      return;
    }

    const tagName = `${release.tag_name || ""}`.trim();
    const version = tagName.replace(/^v/, "");
    const releaseUrl = `${release.html_url || RELEASES_PAGE_URL}`.trim() || RELEASES_PAGE_URL;

    updateReleaseAttributeNodes({ tagName, version, releaseUrl });

    // Material renders repository facts asynchronously and can serve stale cached
    // release tags. We patch the rendered version facts with the latest release.
    const syncSourceFacts = () => {
      updateSourceVersionFacts(tagName);
    };
    syncSourceFacts();

    const observer = new MutationObserver(() => {
      syncSourceFacts();
    });

    observer.observe(document.body, { childList: true, subtree: true });
    window.setTimeout(() => observer.disconnect(), 4000);
  } catch {
    // Leave static content unchanged if release metadata is unavailable.
  }
}

function updateReleaseAttributeNodes({ tagName, version, releaseUrl }) {
  document.querySelectorAll("[data-release-version]").forEach((node) => {
    node.textContent = version || "Unreleased";
  });

  document.querySelectorAll("[data-release-tag]").forEach((node) => {
    node.textContent = tagName || "No release tag";
  });

  document.querySelectorAll("[data-release-link]").forEach((node) => {
    if (node.tagName === "A") {
      node.setAttribute("href", releaseUrl);
    }
  });
}

function updateSourceVersionFacts(tagName) {
  if (!tagName) {
    return;
  }

  document.querySelectorAll(".md-source__fact--version").forEach((node) => {
    if (node.textContent?.trim() !== tagName) {
      node.textContent = tagName;
    }
  });
}

async function loadLatestRelease() {
  const cached = readCachedRelease();
  if (cached != null) {
    return cached;
  }

  const response = await fetch(RELEASES_API_URL, {
    headers: {
      Accept: "application/vnd.github+json",
    },
  });
  if (!response.ok) {
    return null;
  }

  const release = await response.json();
  writeCachedRelease(release);
  return release;
}

function readCachedRelease() {
  try {
    const raw = window.sessionStorage.getItem(RELEASE_CACHE_KEY);
    if (!raw) {
      return null;
    }

    const parsed = JSON.parse(raw);
    const expiresAt = Number(parsed?.expiresAt ?? 0);
    if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
      window.sessionStorage.removeItem(RELEASE_CACHE_KEY);
      return null;
    }

    return parsed.value ?? null;
  } catch {
    return null;
  }
}

function writeCachedRelease(value) {
  try {
    const payload = {
      expiresAt: Date.now() + RELEASE_CACHE_TTL_MS,
      value,
    };
    window.sessionStorage.setItem(RELEASE_CACHE_KEY, JSON.stringify(payload));
  } catch {
    // Ignore cache write failures (private mode / storage restrictions).
  }
}
