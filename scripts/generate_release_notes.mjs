#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execSync } from "node:child_process";

const RELEASE_TAG_RE = /^v(?:(\d{4})\.(\d{2})\.(\d{2})|(\d+)\.(\d+)\.(\d+))$/;
const releaseTag = process.env.RELEASE_TAG;
const releaseVersion = process.env.RELEASE_VERSION || releaseTag?.replace(/^v/, "");
const outputPath = process.env.RELEASE_NOTES_PATH || "dist/release-notes.md";
const productName = process.env.RELEASE_PRODUCT_NAME || "Gia Pha";
const includeInternalUpdates =
  String(process.env.RELEASE_NOTES_INCLUDE_INTERNAL || "false").toLowerCase() ===
  "true";
const maxBulletItems = Number.parseInt(
  process.env.RELEASE_NOTES_MAX_ITEMS || "8",
  10
);

if (!releaseTag) {
  console.error("Missing RELEASE_TAG");
  process.exit(1);
}

function run(command) {
  return execSync(command, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

function listReleaseTags() {
  return run("git tag --list 'v*'")
    .split("\n")
    .map((tag) => tag.trim())
    .filter(Boolean)
    .filter((tag) => RELEASE_TAG_RE.test(tag))
    .sort((a, b) =>
      a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" })
    );
}

function previousTagFor(currentTag, tags) {
  const index = tags.indexOf(currentTag);
  if (index <= 0) {
    return "";
  }
  return tags[index - 1];
}

function refExists(ref) {
  try {
    execSync(`git rev-parse --verify --quiet ${ref}^{commit}`, {
      stdio: ["ignore", "ignore", "ignore"],
    });
    return true;
  } catch {
    return false;
  }
}

function parseCommit(subject) {
  const match = subject.match(/^([a-z]+)(\(([^)]+)\))?!?:\s*(.+)$/i);
  if (!match) {
    return {
      raw: subject,
      type: "update",
      scope: "",
      message: subject,
    };
  }

  return {
    raw: subject,
    type: match[1].toLowerCase(),
    scope: (match[3] || "").trim().toLowerCase(),
    message: (match[4] || "").trim(),
  };
}

function toTitleCase(value) {
  return value
    .split(" ")
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(" ");
}

function normalizeScope(scope) {
  if (!scope) {
    return "";
  }

  const normalized = scope
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();

  const scopeLabels = {
    auth: "Sign in",
    billing: "Billing",
    payments: "Billing",
    payment: "Billing",
    seed: "Data quality",
    fixture: "Data quality",
    fixtures: "Data quality",
    test: "Quality",
    tests: "Quality",
    member: "Members",
    members: "Members",
    profile: "Profile",
    settings: "Settings",
    fund: "Funds",
    funds: "Funds",
    notification: "Notifications",
    notifications: "Notifications",
  };

  return scopeLabels[normalized] || toTitleCase(normalized);
}

function withSentencePunctuation(text) {
  if (!text) {
    return "";
  }

  const trimmed = text.trim();
  if (/[.!?]$/.test(trimmed)) {
    return trimmed;
  }

  return `${trimmed}.`;
}

function humanizeEnglishVerb(text) {
  const transforms = [
    [/^add\b/i, "Added"],
    [/^allow\b/i, "Allowed"],
    [/^fix\b/i, "Fixed"],
    [/^improve\b/i, "Improved"],
    [/^refine\b/i, "Refined"],
    [/^update\b/i, "Updated"],
    [/^remove\b/i, "Removed"],
    [/^enable\b/i, "Enabled"],
    [/^disable\b/i, "Disabled"],
    [/^support\b/i, "Supported"],
    [/^polish\b/i, "Polished"],
    [/^enrich\b/i, "Enriched"],
    [/^stabilize\b/i, "Stabilized"],
    [/^scope\b/i, "Scoped"],
    [/^sync\b/i, "Synced"],
  ];

  for (const [pattern, replacement] of transforms) {
    if (pattern.test(text)) {
      return text.replace(pattern, replacement);
    }
  }

  return text;
}

function cleanSubjectText(subject) {
  let text = subject
    .replace(/\s*\(#\d+\)\s*$/g, "")
    .replace(/\bci\/cd\b/gi, "delivery automation")
    .replace(/\bcicd\b/gi, "delivery automation")
    .replace(/\bci\b/gi, "automation")
    .replace(/\bux\b/gi, "experience")
    .replace(/\bui\b/gi, "interface")
    .replace(/\bqa\b/gi, "quality checks")
    .replace(/\bgithub\b/gi, "GitHub")
    .replace(/\bflutter\b/gi, "Flutter")
    .replace(/\bios\b/gi, "iOS")
    .replace(/\bandroid\b/gi, "Android")
    .replace(/\bentitlement\b/gi, "subscription access")
    .replace(/\band sync\b/gi, "and synced")
    .replace(/\bacross app\b/gi, "across the app")
    .replace(/[_]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (!text) {
    return "";
  }

  text = humanizeEnglishVerb(text);
  text = text.replace(/^Scoped subscriptions\b/i, "Set subscription ownership");

  if (/^[a-z]/.test(text)) {
    text = text.charAt(0).toUpperCase() + text.slice(1);
  }

  return withSentencePunctuation(text);
}

function shouldSkipCommit(commit) {
  const raw = commit.raw.trim();
  const message = commit.message.trim();

  if (!raw || !message) {
    return true;
  }

  if (/^\s*merge\b/i.test(raw)) {
    return true;
  }

  if (/^revert\b/i.test(raw)) {
    return true;
  }

  if (/^chore\(release\):\s*cut v(?:(\d{4})\.(\d{2})\.(\d{2})|(\d+)\.(\d+)\.(\d+))$/i.test(raw)) {
    return true;
  }

  if (/^save current local changes$/i.test(message)) {
    return true;
  }

  if (/^(save|commit)\s+current\b.*\bchanges$/i.test(message)) {
    return true;
  }

  if (/^(wip|tmp|temp|debug)\b/i.test(message)) {
    return true;
  }

  if (/^(cut|bump)\s+v?(?:(\d{4})\.(\d{2})\.(\d{2})|(\d+)\.(\d+)\.(\d+))$/i.test(message)) {
    return true;
  }

  return false;
}

function dedupeByKey(values, keyBuilder) {
  const seen = new Set();
  const result = [];

  for (const value of values) {
    const key = keyBuilder(value);
    if (!key || seen.has(key)) {
      continue;
    }
    seen.add(key);
    result.push(value);
  }

  return result;
}

function normalizeForDedupe(value) {
  return value
    .normalize("NFKD")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, "");
}

function toHumanBullet(commit) {
  const cleaned = cleanSubjectText(commit.message);
  if (!cleaned) {
    return "";
  }

  const scopeLabel = normalizeScope(commit.scope);
  if (!scopeLabel) {
    return `- ${cleaned}`;
  }

  return `- ${scopeLabel}: ${cleaned}`;
}

function isLikelyUserFacing(commit) {
  const text = `${commit.scope} ${commit.message}`.toLowerCase();
  if (/\b(test|fixture|fixtures|seed|mock|stub)\b/.test(text)) {
    return false;
  }

  if (/\b(ci|pipeline|workflow|lint)\b/.test(text)) {
    return false;
  }

  return true;
}

function summarizeFocus(commits) {
  const scopeCounts = new Map();

  for (const commit of commits) {
    const scope = normalizeScope(commit.scope) || "General experience";
    scopeCounts.set(scope, (scopeCounts.get(scope) || 0) + 1);
  }

  const topScopes = Array.from(scopeCounts.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 2)
    .map(([scope]) => scope.toLowerCase());

  if (topScopes.length === 0) {
    return "This release focuses on stability improvements and a smoother day-to-day experience.";
  }

  if (topScopes.length === 1) {
    return `This release focuses on ${topScopes[0]} improvements and day-to-day reliability.`;
  }

  return `This release focuses on ${topScopes.join(
    " and "
  )}, with better reliability across the app.`;
}

const tags = listReleaseTags();
const previousTag = previousTagFor(releaseTag, tags);
const logEndRef = refExists(releaseTag) ? releaseTag : "HEAD";
const logRange = previousTag ? `${previousTag}..${logEndRef}` : logEndRef;

const rawSubjects = run(`git log --no-merges --pretty=format:%s ${logRange}`)
  .split("\n")
  .map((line) => line.trim())
  .filter(Boolean);

const commits = rawSubjects
  .map(parseCommit)
  .filter((commit) => !shouldSkipCommit(commit));

const userFacingTypes = new Set(["feat", "fix", "perf", "refactor"]);
const userFacingCommits = commits.filter((commit) => userFacingTypes.has(commit.type));
const internalCommits = commits.filter((commit) => !userFacingTypes.has(commit.type));
const prioritizedUserFacingCommits = userFacingCommits.filter(isLikelyUserFacing);
const candidateUserFacingCommits =
  prioritizedUserFacingCommits.length > 0
    ? prioritizedUserFacingCommits
    : userFacingCommits;

const selectedUserFacingCommits = dedupeByKey(candidateUserFacingCommits, (commit) =>
  normalizeForDedupe(`${commit.scope}:${commit.message}`)
).slice(0, Number.isFinite(maxBulletItems) ? Math.max(1, maxBulletItems) : 8);

const friendlyBullets = selectedUserFacingCommits.map(toHumanBullet).filter(Boolean);
const selectedInternalBullets = includeInternalUpdates
  ? dedupeByKey(internalCommits, (commit) =>
      normalizeForDedupe(`${commit.scope}:${commit.message}`)
    )
      .map(toHumanBullet)
      .filter(Boolean)
      .slice(0, 4)
  : [];

if (friendlyBullets.length === 0) {
  friendlyBullets.push(
    "- Improved overall stability and the day-to-day experience."
  );
}

const lines = [
  `# ${productName} v${releaseVersion}`,
  "",
  `Thanks for using ${productName}.`,
  "",
  "## What is new for you",
  ...friendlyBullets,
  ...(selectedInternalBullets.length > 0
    ? ["", "## Behind the scenes", ...selectedInternalBullets]
    : []),
  "",
  "## Why this release matters",
  summarizeFocus(selectedUserFacingCommits),
  "",
  "## Update rollout",
  "- Staging builds can be verified before production promotion.",
  "- Production users will receive the update after release publish completes.",
];

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${lines.join("\n")}\n`, "utf8");
console.log(`Friendly release notes written to ${outputPath}`);
