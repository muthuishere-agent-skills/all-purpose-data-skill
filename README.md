# all-purpose-data-skill

A Claude Code / Codex agent skill that turns natural-language productivity requests — *"send an email to X"*, *"what's on my calendar"*, *"find last week's Teams recording"*, *"export this Google Doc as PDF"*, *"my PRs"*, *"morning brief"* — into authenticated HTTP calls across **Google Workspace**, **Microsoft 365**, and **GitHub**. The headline flow is **Morning Brief**: one turn aggregates today's meetings, unread mail, new Teams messages, and your GitHub PR / issue queue.

The skill is the *routing + recipe layer*. It knows which family an intent belongs to (mail, calendar, Teams, meetings, files, contacts), which provider can serve it, which handle to use, and the exact HTTP shape. It does **not** handle OAuth — that job belongs to [`apl`](https://github.com/muthuishere/all-purpose-login).

---

## Requirements

### Always required

| Tool | For | Install |
|---|---|---|
| **Claude Code** or **Codex** | The agent runtime loading this skill | https://claude.com/claude-code |
| **`apl`** | OAuth broker — this skill's engine | `npm install -g @muthuishere/apl` |
| **Node 20+** | Only if installing `apl` via npm | `brew install node` |

That's the minimum for the skill to load. Without at least one configured `apl` handle, the skill will prompt you to run setup on first use.

### Only if you want Microsoft features (mail / calendar / Teams / meetings / OneDrive / SharePoint)

| Tool | For | Install |
|---|---|---|
| **`az`** CLI | `apl setup ms` — automates Azure AD app registration + Graph scope grants | `brew install azure-cli` |

Then `az login` once. See [`references/setup-microsoft.md`](./references/setup-microsoft.md) for the full flow.

### Only if you want Google features (Gmail / Calendar / Drive / Meet / Contacts)

| Tool | For | Install |
|---|---|---|
| **`gcloud`** CLI | `apl setup google` — picks/creates GCP project, enables APIs | `brew install --cask google-cloud-sdk` |

Then `gcloud auth login` once. The OAuth Client ID creation has one unavoidable manual step in the GCP console (Google blocks `gcloud` from doing it). See [`references/setup-google.md`](./references/setup-google.md).

### Only if you want GitHub features (PRs / issues / reviews / Actions / releases / Morning Brief's GitHub section)

| Tool | For | Install |
|---|---|---|
| **`gh`** (GitHub CLI) | Auth + every GitHub recipe in `references/github.md` | `brew install gh` |

Then `gh auth login` once. Without `gh`, the rest of the skill still works — only the GitHub recipes and Morning Brief's GitHub sections are disabled.

### Never required

- **Both cloud CLIs.** If you only use Google, no `az` needed; if you only use Microsoft, no `gcloud` needed. Install only what matches the APIs you'll hit.
- **An active cloud subscription / billing account.** The Azure app registration is free on a tenant-level account; the GCP project is free for personal Gmail use under testing-mode OAuth (100-user cap, plenty for personal use).
- **Python, Docker, any package manager besides npm** beyond what your OS ships.

---

## Install

```bash
# 1. Install the OAuth broker
npm install -g @muthuishere/apl

# 2. Install this skill (symlinks into ~/.claude/skills/; also ~/.agents/skills/ if codex is on PATH)
git clone https://github.com/muthuishere-agent-skills/all-purpose-data-skill
cd all-purpose-data-skill
sh install.sh

# 3. Configure whichever providers you want (both optional; pick what you need)
apl setup ms           # needs az
apl setup google       # needs gcloud

# 4. Log in
apl login ms:work
apl login google:personal

# 5. Restart your agent session to pick up the skill
```

Override the Claude skills dir:

```bash
CLAUDE_SKILLS_DIR=/some/other/path sh install.sh
```

---

## Uninstall

```bash
sh uninstall.sh                       # removes skill symlinks
npm uninstall -g @muthuishere/apl     # removes apl itself
```

`apl`'s tokens live in your OS keychain; removing the binary doesn't delete them. To wipe tokens: `apl logout <handle>` per account, or clear the `all-purpose-login` service from your OS keychain directly.

---

## Relationship to `apl`

| | `apl` | this skill |
|---|---|---|
| Role | OAuth token broker + HTTP relay | Intent router + recipe catalogue |
| Handles OAuth | yes | no |
| Stores tokens | yes (encrypted, OS keychain) | no — never touches apl's store |
| Prompts for credentials | only via `apl setup` / browser OAuth | never |
| Install | `npm install -g @muthuishere/apl` | `sh install.sh` |

The skill calls `apl` via five commands only:

- `apl version` — preflight
- `apl accounts --json` — list configured handles
- `apl setup google` / `apl setup ms` — first-time provider setup (one-time)
- `apl login <handle> [--force] [--scope ...]` — obtain / refresh record
- `apl call <handle> <METHOD> "<url>" [flags]` — authenticated HTTP request

That's the entire surface. The skill never reads `~/.config/apl/…` directly and never asks the user for a client id, secret, tenant, or token.

---

## Typical session

1. You: *"what's in my inbox"*
2. Skill runs `apl accounts --json`, lists handles, asks which to use.
3. You: *"google:work"*
4. Skill runs `apl call google:work GET "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=is:unread&maxResults=20"`, renders a list.
5. You: *"send an email to x@y.com saying hi"*
6. Skill builds the RFC-2822 body, POSTs via Gmail `messages/send`, confirms with the returned id.

Switch accounts mid-session: *"use my personal gmail instead"* → picker re-prompts.

---

## What's inside

- [`SKILL.md`](./SKILL.md) — agent manifest + frontmatter triggers + core rules
- [`references/workflow.md`](./references/workflow.md) — preflight, handle selection, intent routing, failure handling
- [`references/handle-selection.md`](./references/handle-selection.md) — picker + provider compatibility table
- [`references/setup-google.md`](./references/setup-google.md) — what `apl setup google` does + troubleshooting
- [`references/setup-microsoft.md`](./references/setup-microsoft.md) — what `apl setup ms` does + troubleshooting
- [`references/mail.md`](./references/mail.md) — Gmail + Graph Mail (read/send/search/attachments/labels/delta)
- [`references/calendar.md`](./references/calendar.md) — Google Calendar + Graph Calendar (today/week/RSVP/free-busy/Meet+Teams links)
- [`references/teams-chat.md`](./references/teams-chat.md) — 1:1 / group / meeting / channel messages, reactions, replies (Microsoft)
- [`references/online-meetings.md`](./references/online-meetings.md) — meeting lookup, recordings, transcripts, 403-wall workarounds (Microsoft)
- [`references/drive.md`](./references/drive.md) — OneDrive / SharePoint + Google Drive (search/download/upload/export/share/perms)
- [`references/contacts.md`](./references/contacts.md) — Microsoft Contacts / directory + Google People
- [`references/delta-and-batch.md`](./references/delta-and-batch.md) — Gmail history, Calendar syncToken, Mail/Events delta, Drive changes, `$batch`, Gmail multipart batch, webhook subscriptions
- [`references/github.md`](./references/github.md) — repos, PRs, issues, reviews, Actions, releases, code/issue/PR search (via `gh` CLI)
- [`references/morning-brief.md`](./references/morning-brief.md) — headline flow; aggregates across mail + calendar + Teams + GitHub in one turn

Each reference file declares the apl spec commit it was generated from at the top.

---

## Upstream

For deeper OAuth setup docs (Azure app registration internals, GCP project setup, scope requirements, recording-download limitations), see the `apl` repo:

**https://github.com/muthuishere/all-purpose-login**

Specifically:
- [`docs/microsoft-graph.md`](https://github.com/muthuishere/all-purpose-login/blob/main/docs/microsoft-graph.md) — all verified Graph URLs, scope tables, recording-download gotchas
- [`docs/google-apis.md`](https://github.com/muthuishere/all-purpose-login/blob/main/docs/google-apis.md) — same for Google
- [`docs/specs/spec-recipes.md`](https://github.com/muthuishere/all-purpose-login/blob/main/docs/specs/spec-recipes.md) — the 150-recipe catalogue this skill is derived from

---

## Troubleshooting

**Skill doesn't load after install** — Restart your Claude Code / Codex session. The agent reads skills at startup.

**"`apl` not found" in skill output** — Run `npm install -g @muthuishere/apl`. Check `$(npm prefix -g)/bin` is on your PATH.

**Microsoft intents prompt for google handle (or vice versa)** — Say *"use my MS account"* / *"use ms:work"* and the skill re-picks.

**403 on Teams meeting recording mp4** — SharePoint ACL wall, not a skill bug. The skill's `online-meetings.md` recipe walks you through a workaround (share-link retry pattern). Full explanation in `apl`'s `docs/microsoft-graph.md`.

**OAuth consent screen 403 / 400 on first login** — Google's backend propagation lag after you just created the OAuth client in the console; wait 5 minutes and retry. See `apl`'s troubleshooting.

---

## License

MIT — see [`LICENSE`](./LICENSE).
