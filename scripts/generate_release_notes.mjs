#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execSync } from "node:child_process";

const releaseTag = process.env.RELEASE_TAG;
const releaseVersion = process.env.RELEASE_VERSION || releaseTag?.replace(/^v/, "");
const outputPath = process.env.RELEASE_NOTES_PATH || "dist/release-notes.md";
const productName = process.env.RELEASE_PRODUCT_NAME || "Gia Pha";

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

function listSemverTags() {
  return run("git tag --list 'v*'")
    .split("\n")
    .map((tag) => tag.trim())
    .filter(Boolean)
    .filter((tag) => /^v\d+\.\d+\.\d+$/.test(tag))
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

function parseType(subject) {
  const match = subject.match(/^([a-z]+)(\([^)]+\))?!?:/i);
  return match ? match[1].toLowerCase() : "update";
}

function cleanSubject(subject) {
  let text = subject
    .replace(/^([a-z]+)(\([^)]+\))?!?:\s*/i, "")
    .replace(/\s*\(#\d+\)\s*$/g, "")
    .replace(/\s+/g, " ")
    .trim();

  if (!text) {
    return "";
  }

  if (/^cut v\d+\.\d+\.\d+$/i.test(text)) {
    return "";
  }

  text = text
    .replace(/\bci\/cd\b/gi, "delivery workflow")
    .replace(/\bci\b/gi, "automation")
    .replace(/\bcicd\b/gi, "delivery workflow")
    .replace(/\bui\b/gi, "interface")
    .replace(/\bgithub\b/g, "GitHub")
    .replace(/\bflutter\b/g, "Flutter")
    .replace(/\bios\b/gi, "iOS")
    .replace(/\bandroid\b/gi, "Android")
    .replace(/[_/]/g, " ");

  text = text.charAt(0).toUpperCase() + text.slice(1);
  if (!/[.!?]$/.test(text)) {
    text += ".";
  }

  return text;
}

const verbByType = {
  feat: "Added",
  fix: "Improved",
  perf: "Made faster",
  refactor: "Improved",
  docs: "Updated guides",
  ci: "Improved delivery",
  chore: "Polished",
  build: "Updated release pipeline",
  test: "Improved confidence",
};

const tags = listSemverTags();
const previousTag = previousTagFor(releaseTag, tags);
const logRange = previousTag ? `${previousTag}..HEAD` : "HEAD";

const rawSubjects = run(`git log --no-merges --pretty=format:%s ${logRange}`)
  .split("\n")
  .map((line) => line.trim())
  .filter(Boolean)
  .filter((subject) => !/^\s*merge\b/i.test(subject))
  .filter((subject) => !/^chore\(release\):\s*cut v\d+\.\d+\.\d+$/i.test(subject));

const friendlyBullets = rawSubjects
  .map((subject) => {
    const type = parseType(subject);
    const cleaned = cleanSubject(subject);
    if (!cleaned) {
      return "";
    }
    const verb = verbByType[type] || "Updated";
    return `- ${verb}: ${cleaned}`;
  })
  .filter(Boolean)
  .slice(0, 10);

if (friendlyBullets.length === 0) {
  friendlyBullets.push(
    "- Improved overall stability, release readiness, and day-to-day experience."
  );
}

const lines = [
  `# ${productName} v${releaseVersion}`,
  "",
  `Thanks for using ${productName}.`,
  "",
  "## What is new for you",
  ...friendlyBullets,
  "",
  "## Why this release matters",
  "This update improves reliability, delivery quality, and the day-to-day experience for family and clan management.",
  "",
  "## Update rollout",
  "- Staging builds can be verified before production promotion.",
  "- Production users will receive the update after release publish completes.",
];

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${lines.join("\n")}\n`, "utf8");
console.log(`Friendly release notes written to ${outputPath}`);
