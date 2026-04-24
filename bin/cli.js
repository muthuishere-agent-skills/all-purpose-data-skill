#!/usr/bin/env node
// all-purpose-data-skill CLI — installs / uninstalls the skill into the
// Claude Code (and Codex, when present) skills directory by symlinking the
// packaged skill content.
//
// Usage:
//   all-purpose-data-skill install
//   all-purpose-data-skill uninstall
//   all-purpose-data-skill where
//
// Skills dir resolution:
//   $CLAUDE_SKILLS_DIR  (override)  ELSE  $HOME/.claude/skills

"use strict";

const fs = require("fs");
const path = require("path");
const os = require("os");

const SKILL_NAME = "all-purpose-data-skill";
const PKG_ROOT = path.resolve(__dirname, "..");

function claudeSkillsDir() {
  if (process.env.CLAUDE_SKILLS_DIR) return process.env.CLAUDE_SKILLS_DIR;
  return path.join(os.homedir(), ".claude", "skills");
}

function codexSkillsDir() {
  return path.join(os.homedir(), ".agents", "skills");
}

function hasCodex() {
  // Lightweight check — is `codex` on PATH?
  const pathDirs = (process.env.PATH || "").split(path.delimiter);
  for (const d of pathDirs) {
    try {
      if (fs.existsSync(path.join(d, "codex"))) return true;
    } catch (_) {}
  }
  return false;
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function linkOne(targetDir, label) {
  ensureDir(targetDir);
  const linkPath = path.join(targetDir, SKILL_NAME);
  let existing = null;
  try {
    existing = fs.lstatSync(linkPath);
  } catch (_) {}

  if (existing) {
    if (existing.isSymbolicLink()) {
      fs.unlinkSync(linkPath);
    } else {
      console.error(
        `✗ ${label}: ${linkPath} is not a symlink — refusing to clobber.`
      );
      return false;
    }
  }
  fs.symlinkSync(PKG_ROOT, linkPath);
  console.log(`  ${label} → ${linkPath}`);
  return true;
}

function unlinkOne(targetDir, label) {
  const linkPath = path.join(targetDir, SKILL_NAME);
  let existing = null;
  try {
    existing = fs.lstatSync(linkPath);
  } catch (_) {
    console.log(`  ${label}: not installed, skipping`);
    return true;
  }
  if (!existing.isSymbolicLink()) {
    console.error(
      `✗ ${label}: ${linkPath} is not a symlink — refusing to remove.`
    );
    return false;
  }
  fs.unlinkSync(linkPath);
  console.log(`  ${label}: removed ${linkPath}`);
  return true;
}

function cmdInstall() {
  console.log(`Installing ${SKILL_NAME} from ${PKG_ROOT}`);
  let ok = true;
  ok = linkOne(claudeSkillsDir(), "Claude Code") && ok;
  if (hasCodex()) {
    ok = linkOne(codexSkillsDir(), "Codex Agent") && ok;
  } else {
    console.log("  Codex Agent — not installed, skipping");
  }
  if (!ok) process.exit(1);
  console.log("\nDone. Restart your agent session to pick up the new skill.");
}

function cmdUninstall() {
  console.log(`Uninstalling ${SKILL_NAME}`);
  let ok = true;
  ok = unlinkOne(claudeSkillsDir(), "Claude Code") && ok;
  ok = unlinkOne(codexSkillsDir(), "Codex Agent") && ok;
  if (!ok) process.exit(1);
  console.log("\nDone.");
}

function cmdWhere() {
  console.log(`pkg root        ${PKG_ROOT}`);
  console.log(`claude skills   ${claudeSkillsDir()}`);
  console.log(`codex skills    ${codexSkillsDir()} ${hasCodex() ? "(codex on PATH)" : "(codex not found)"}`);
}

const cmd = (process.argv[2] || "").toLowerCase();
switch (cmd) {
  case "install":   cmdInstall();   break;
  case "uninstall": cmdUninstall(); break;
  case "where":     cmdWhere();     break;
  default:
    console.error(
`all-purpose-data-skill — Claude Code / Codex agent skill installer

Usage:
  all-purpose-data-skill install     Symlink the skill into Claude Code (+ Codex if installed)
  all-purpose-data-skill uninstall   Remove the symlinks
  all-purpose-data-skill where       Print resolved skill + agent directories

One-shot install:
  npx @muthuishere/all-purpose-data-skill install

Global install (then use the short command):
  npm install -g @muthuishere/all-purpose-data-skill
  all-purpose-data-skill install
`
    );
    process.exit(cmd ? 1 : 0);
}
