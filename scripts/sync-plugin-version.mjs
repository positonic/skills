#!/usr/bin/env node
// Copy package.json's version into .claude-plugin/plugin.json.
//
// Changesets only writes package.json, but Claude Code decides whether installed
// users see an update from the plugin manifest's version — so the two must not
// drift (see CLAUDE.md). The Release workflow runs this straight after
// `changeset version`, so the bot's version PR bumps both files together.

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const pluginManifest = join(repoRoot, ".claude-plugin", "plugin.json");

const { version } = JSON.parse(
  readFileSync(join(repoRoot, "package.json"), "utf8"),
);

const source = readFileSync(pluginManifest, "utf8");

// Anchored to a top-level key (2-space indent) so a nested "version" can't match.
const topLevelVersion = /^(  "version": )"[^"]*"/m;

if (!topLevelVersion.test(source)) {
  console.error(
    `No top-level "version" key in ${pluginManifest} — cannot sync to ${version}.`,
  );
  process.exit(1);
}

const updated = source.replace(
  topLevelVersion,
  (_match, key) => `${key}${JSON.stringify(version)}`,
);

if (updated === source) {
  console.log(`plugin.json already at ${version}`);
} else {
  writeFileSync(pluginManifest, updated);
  console.log(`plugin.json synced to ${version}`);
}
