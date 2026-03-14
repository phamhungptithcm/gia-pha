#!/usr/bin/env node

import fs from "node:fs";
import process from "node:process";
import { execSync } from "node:child_process";

const SEMVER_RE = /^v(\d+)\.(\d+)\.(\d+)$/;

function run(command) {
  return execSync(command, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

function readLines(command) {
  const output = run(command);
  if (!output) {
    return [];
  }

  return output
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function compareTags(a, b) {
  return a.localeCompare(b, undefined, {
    numeric: true,
    sensitivity: "base",
  });
}

function listSemverTags(command) {
  return readLines(command)
    .filter((tag) => SEMVER_RE.test(tag))
    .sort(compareTags);
}

function parseVersion(value) {
  const match = value.match(SEMVER_RE);
  if (!match) {
    throw new Error(`Invalid semver tag: ${value}`);
  }

  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
  };
}

function previousTagFor(currentTag, tags) {
  const index = tags.indexOf(currentTag);
  if (index <= 0) {
    return "";
  }

  return tags[index - 1];
}

function detectBump(logRange) {
  const rawMessages = run(
    `git log --no-merges --pretty=format:%s%n%b%x1e ${logRange}`
  );

  const messages = rawMessages
    .split("\x1e")
    .map((message) => message.trim())
    .filter(Boolean);

  let bump = "patch";

  for (const message of messages) {
    if (
      /\bBREAKING CHANGE\b/i.test(message) ||
      /^([a-z]+)(\([^)]+\))?!:/im.test(message)
    ) {
      return "major";
    }

    if (/^feat(\([^)]+\))?:/im.test(message)) {
      bump = "minor";
    }
  }

  return bump;
}

function bumpVersion(previousTag, bump) {
  if (!previousTag) {
    return "0.1.0";
  }

  const { major, minor, patch } = parseVersion(previousTag);

  if (bump === "major") {
    return `${major + 1}.0.0`;
  }

  if (bump === "minor") {
    return `${major}.${minor + 1}.0`;
  }

  return `${major}.${minor}.${patch + 1}`;
}

function buildNumberFor(version) {
  const [major, minor, patch] = version.split(".").map(Number);
  return String(major * 10000 + minor * 100 + patch);
}

function emitOutput(payload) {
  const outputLines = Object.entries(payload).map(
    ([key, value]) => `${key}=${value}`
  );

  if (process.env.GITHUB_OUTPUT) {
    fs.appendFileSync(
      process.env.GITHUB_OUTPUT,
      `${outputLines.join("\n")}\n`,
      "utf8"
    );
  }

  console.log(JSON.stringify(payload, null, 2));
}

const tags = listSemverTags("git tag --list 'v*'");
const headTags = listSemverTags("git tag --points-at HEAD");
const currentTag = headTags.at(-1);

if (currentTag) {
  const currentVersion = currentTag.replace(/^v/, "");
  emitOutput({
    tag: currentTag,
    version: currentVersion,
    build_number: buildNumberFor(currentVersion),
    previous_tag: previousTagFor(currentTag, tags),
    bump: "existing",
    head_already_tagged: "true",
  });
  process.exit(0);
}

const previousTag = tags.at(-1) || "";
const logRange = previousTag ? `${previousTag}..HEAD` : "HEAD";
const bump = detectBump(logRange);
const version = bumpVersion(previousTag, bump);

emitOutput({
  tag: `v${version}`,
  version,
  build_number: buildNumberFor(version),
  previous_tag: previousTag,
  bump,
  head_already_tagged: "false",
});
