#!/usr/bin/env node

import { execSync } from "node:child_process";
import fs from "node:fs";
import process from "node:process";

const DATE_TAG_RE = /^v(\d{4})\.(\d{2})\.(\d{2})$/;
const LEGACY_SEMVER_RE = /^v(\d+)\.(\d+)\.(\d+)$/;
const RELEASE_TAG_RE = /^v(?:(\d{4})\.(\d{2})\.(\d{2})|(\d+)\.(\d+)\.(\d+))$/;

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

function isReleaseTag(tag) {
  return RELEASE_TAG_RE.test(tag);
}

function listReleaseTags(command) {
  return readLines(command)
    .filter((tag) => isReleaseTag(tag))
    .sort(compareTags);
}

function previousTagFor(currentTag, tags) {
  const index = tags.indexOf(currentTag);
  if (index <= 0) {
    return "";
  }

  return tags[index - 1];
}

function buildNumberForLegacyVersion(version) {
  const [major, minor, patch] = version.split(".").map(Number);
  return String(major * 10000 + minor * 100 + patch);
}

function buildNumberForTag(tag) {
  const dateMatch = tag.match(DATE_TAG_RE);
  if (dateMatch) {
    return `${dateMatch[1]}${dateMatch[2]}${dateMatch[3]}`;
  }

  const legacyVersion = tag.replace(/^v/, "");
  return buildNumberForLegacyVersion(legacyVersion);
}

function formatDateVersion(date, timeZone) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = formatter.formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}.${values.month}.${values.day}`;
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

const releaseTimeZone = process.env.RELEASE_TIMEZONE || "Asia/Ho_Chi_Minh";
const tags = listReleaseTags("git tag --list 'v*'");
const headTags = listReleaseTags("git tag --points-at HEAD");
const currentTag = headTags.at(-1);

if (currentTag) {
  const currentVersion = currentTag.replace(/^v/, "");
  emitOutput({
    tag: currentTag,
    version: currentVersion,
    build_number: buildNumberForTag(currentTag),
    previous_tag: previousTagFor(currentTag, tags),
    bump: "existing",
    head_already_tagged: "true",
  });
  process.exit(0);
}

const previousTag = tags.at(-1) || "";
const version = formatDateVersion(new Date(), releaseTimeZone);
const tag = `v${version}`;

if (tags.includes(tag)) {
  console.error(
    `Release tag ${tag} already exists on another commit. This pipeline supports one main release tag per day.`
  );
  process.exit(1);
}

emitOutput({
  tag,
  version,
  build_number: buildNumberForTag(tag),
  previous_tag: previousTag,
  bump: "date",
  head_already_tagged: "false",
});
