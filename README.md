# all-purpose-data-skill

A Claude Code / Codex agent skill that turns natural-language productivity
requests — "send an email to X", "what's on my calendar", "find last week's
Teams recording", "export this Google Doc as PDF" — into authenticated HTTP
calls against Google Workspace and Microsoft 365.

## What it does

The skill is the *routing and recipe layer*. It knows:

- Which family a user intent belongs to (mail, calendar, Teams chat,
  online meetings, files, contacts, delta/batch).
- Which provider can serve it (Gmail vs Graph Mail, Google Drive vs
  OneDrive, Google People vs Microsoft directory).
- Which handle (`google:work`, `ms:volentis`, …) to use.
- The exact HTTP endpoint + method + body + scopes for each recipe.
- The documented workarounds for the platform walls (SharePoint ACLs on
  Teams recordings, DLP quarantine, tenant policy 403s).

It does NOT know how to authenticate. That job belongs to `apl`.

## Relationship to `apl`

| | `apl` | this skill |
|---|---|---|
| Role | OAuth token broker + HTTP relay | Intent router + recipe catalogue |
| Handles OAuth | yes (Google + Microsoft) | no |
| Stores tokens | yes | no — never touches `apl`'s store |
| Prompts for credentials | only via `apl setup` / browser OAuth | never |
| Installation | `npm install -g @muthuishere/apl` | `sh install.sh` |

The skill calls `apl` by:

- `apl version` — preflight (is it installed?).
- `apl accounts --json` — list configured handles.
- `apl setup google` / `apl setup ms` — first-time OAuth client registration.
- `apl login <handle> [--force] [--scope <s>]` — obtain / refresh a stored
  record.
- `apl call <handle> <METHOD> "<url>" [flags]` — make the authenticated HTTP
  request.

That's the entire command surface. The skill never reads `~/.config/apl/…`
directly and never prompts the user for a client id, client secret, tenant
id, app password, or token.

## Install

1. **Install `apl`** (the OAuth broker):

   ```bash
   npm install -g @muthuishere/apl
   ```

2. **Install this skill** (symlinks into `~/.claude/skills/` and, if `codex`
   is on PATH, also `~/.agents/skills/`):

   ```bash
   sh install.sh
   ```

   Override the Claude skills dir with `CLAUDE_SKILLS_DIR`:

   ```bash
   CLAUDE_SKILLS_DIR=/some/other/path sh install.sh
   ```

3. **Configure at least one account** (one-time per provider):

   ```bash
   apl setup google       # picker-driven: pick/create GCP project, paste Client ID
   apl setup ms           # picker-driven: pick/create Azure app registration
   ```

4. **Log in** with the handle(s) you'll use:

   ```bash
   apl login google:work
   apl login ms:volentis
   ```

5. **Restart your agent session** to pick up the new skill.

Where the skill lives after install:

- `~/.claude/skills/all-purpose-data-skill` (symlink)
- `~/.agents/skills/all-purpose-data-skill` (symlink, if `codex` is on PATH)

## Uninstall

```bash
sh uninstall.sh            # removes skill symlinks
npm uninstall -g @muthuishere/apl   # removes apl
```

## Typical session

1. You: *"what's in my inbox"*
2. Skill: runs `apl accounts --json`, lists handles:
   ```
   Google:     google:work
   Microsoft:  ms:volentis
   ```
3. You: *"google:work"*
4. Skill: runs `apl call google:work GET "<gmail>/messages?q=is:unread&maxResults=20"`, fetches headers for each, renders a list.
5. You: *"send an email to x@y.com saying hi from the skill"*
6. Skill: builds RFC-2822 raw body, posts via Gmail `messages/send`, confirms with the returned message id.

Switch at any time: *"use my personal gmail instead"* → skill re-prompts the
picker.

## What's in here

- [`SKILL.md`](./SKILL.md) — agent manifest + frontmatter triggers + core rules.
- [`references/workflow.md`](./references/workflow.md) — preflight, handle
  selection, intent routing, failure handling.
- [`references/handle-selection.md`](./references/handle-selection.md) —
  picker + compatibility table (what's Microsoft-only, Google-only, or
  mirrored).
- [`references/setup-google.md`](./references/setup-google.md) — what
  `apl setup google` does + troubleshooting.
- [`references/setup-microsoft.md`](./references/setup-microsoft.md) — what
  `apl setup ms` does + troubleshooting.
- [`references/mail.md`](./references/mail.md) — Gmail + Graph Mail
  (read, send, search, attachments, labels, delta).
- [`references/calendar.md`](./references/calendar.md) — Google Calendar +
  Graph Calendar (today / week / upcoming / RSVP / free-busy / Meet / Teams
  link).
- [`references/teams-chat.md`](./references/teams-chat.md) — 1:1 / group /
  meeting / channel messages, reactions, replies (Microsoft-only).
- [`references/online-meetings.md`](./references/online-meetings.md) —
  meeting lookup, recordings, transcripts, and the known 403 walls
  (Microsoft-only).
- [`references/drive.md`](./references/drive.md) — OneDrive / SharePoint +
  Google Drive (search, download, upload, export, share, permissions).
- [`references/contacts.md`](./references/contacts.md) — Microsoft Contacts /
  directory + Google People.
- [`references/delta-and-batch.md`](./references/delta-and-batch.md) — Gmail
  history, Calendar syncToken, Mail delta, Events delta, Drive changes,
  `$batch`, Gmail multipart batch, webhook subscriptions.

## Upstream

For OAuth setup depths (Azure app registration, GCP project setup), see the
`apl` repo:
https://github.com/muthuishere/all-purpose-login

The recipe catalogue that drives this skill lives at
`docs/specs/spec-recipes.md` in that repo. Each reference file in
`references/` declares the spec commit it was generated from at the top of
the file.

## License

MIT. See [`LICENSE`](./LICENSE).
