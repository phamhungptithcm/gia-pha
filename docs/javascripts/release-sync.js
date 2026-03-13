document$.subscribe(async () => {
  const releaseNodes = document.querySelectorAll("[data-release-version], [data-release-tag], [data-release-link]");
  if (releaseNodes.length === 0) {
    return;
  }

  try {
    const response = await fetch("https://api.github.com/repos/phamhungptithcm/gia-pha/releases/latest");
    if (!response.ok) {
      return;
    }

    const release = await response.json();
    const tagName = release.tag_name || "";
    const version = tagName.replace(/^v/, "");
    const releaseUrl = release.html_url || "https://github.com/phamhungptithcm/gia-pha/releases";

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
  } catch {
    // Leave the static page content unchanged if release metadata is unavailable.
  }
});
