---
name: all-purpose-data-skill
description: >
  Email, calendar, Teams chat, online meetings (recordings + transcripts),
  Drive / OneDrive / SharePoint files, contacts, and GitHub (PRs, issues,
  reviews, Actions, releases) across Google Workspace, Microsoft 365, and
  GitHub. Headline flow: Morning Brief — aggregates meetings + mail + chat
  + PRs/issues in one turn. Uses `apl`
  (`npm install -g @muthuishere/apl`) as the OAuth token broker and `gh`
  for GitHub. Trigger on: morning brief, catch me up, what's on today,
  start my day, my prs, review queue, my issues, pr status, new messages,
  what's new, anything new, send/read/reply/forward/search email, unread
  mail, today's / this week's / next meeting, create / decline / RSVP
  event, free-busy, meeting recording + transcript, search teams chat,
  dm on teams, post in channel, react, search drive / onedrive /
  sharepoint, download or export file, share file, look up contact, find
  person in directory, sync since last check, batch calls. Works across
  google:<label> and ms:<label> handles from `apl accounts`.
---

<!-- version: 0.1.0 -->

# all-purpose-data-skill

A natural-language front door for Google Workspace + Microsoft 365 productivity
APIs (mail, calendar, meetings, Teams, files, contacts). Token brokerage is
fully delegated to [`apl`](https://www.npmjs.com/package/@muthuishere/apl); this
skill carries the routing and recipe knowledge.

## Core Rules

- **`apl` is the auth engine. This skill never handles credentials.** Setup
  goes through `apl setup google` / `apl setup ms`. Login goes through
  `apl login <handle>`. Read those names only — never prompt the user for a
  client id, client secret, tenant id, pasted token, or refresh token.
- **Prefer `apl call` first.** It owns bearer injection and 401 refresh-retry.
  Fall back to `TOKEN=$(apl login <handle>) && curl …` ONLY when the recipe
  documents that exception (binary upload streams, SharePoint pre-authed
  download URLs, multipart/mixed batch). The reference files mark those
  cases explicitly with "Fallback:".
- **Never print the access token.** Any `apl login` output is piped into the
  consuming command, never echoed back to the user. Never show it in a code
  fence.
- **Fan out across all compatible handles by default.** On any intent
  that can be served by multiple handles (mail / calendar / contacts /
  drive — anything provider-agnostic), run `apl accounts --json`, and
  issue the corresponding `apl call` to every compatible handle **in
  parallel**. Aggregate results before presenting. Do not prompt the user
  to pick — the whole point of "all-purpose-data" is the cross-provider
  view in one shot.
- **Label aggregated items by source.** When merging results from
  multiple handles (e.g. 10 unread mails across Gmail + Outlook), prefix
  or tag each with its handle so the user can trace provenance.
- **Provider-specific intents still route.** Microsoft-only (Teams,
  online meetings) — use the ms handle. Google-only (Google Docs export,
  Meet recordings via Drive) — use the google handle. With exactly one
  compatible handle, proceed silently. With zero, tell the user what's
  missing and how to set up.
- **User override takes precedence.** Phrases like "just my work gmail",
  "only reqsume", "use ms:volentis" narrow the fan-out to that single
  handle for the remainder of the session (or until switched again).
- **Cache the set of handles in conversation context** — don't re-run
  `apl accounts --json` on every recipe. Refresh on `apl login` /
  `apl logout` / explicit "refresh handles".
- **Surface walls honestly.** A 403 driven by tenant policy or SharePoint ACL
  (e.g. Teams recording `/content` endpoint, DLP block, admin-consent
  required) is NOT retried. Report the wall, cite the documented workaround
  from the relevant reference, and stop.
- **Default to signal, not noise.** A generic ask like "what are my emails
  today" means the user wants the ~10 items they'd actually open, not a
  dump of every newsletter + transactional + bank alert. Default filters:
  - **Gmail:** `q=in:inbox category:primary is:unread newer_than:1d` (skips
    Promotions, Updates, Social, Forums). Cap `maxResults=20`.
  - **Graph Mail:** `$filter=isRead eq false and parentFolderId ne <Junk
    Email>`; order by `receivedDateTime desc`, `$top=20`.
  - Summarize by sender + subject; do NOT categorize the whole inbox.
  Upgrade to broader queries only when the user explicitly asks:
  "all mail", "including newsletters", "read + unread", "last 7 days".
- **Never dump >30 items in a single response.** If a query returns more,
  summarize a count + top-N actionable, offer to expand categories on
  request. Agents burn user tokens on bulk list formatting — keep it terse.

## Session Context

Held in conversation memory only — no file writes.

```
all_handles:      [google:muthuishere, ms:reqsume, ...]   # from `apl accounts --json`
scope_override:   null                                     # or "google:muthuishere" if user narrowed
```

Default behavior: fan out across `all_handles` (filtered by provider
compatibility for the current intent). `scope_override` narrows the
set to a single handle when the user says so.

If the session ends, the skill re-lists handles next time.

## Process

1. Read `references/workflow.md` for preflight, handle-selection, intent
   routing, and failure handling.
2. For handle choice and compatibility, consult `references/handle-selection.md`.
3. For first-time OAuth setup, route to:
   - Google → `references/setup-google.md`
   - Microsoft → `references/setup-microsoft.md`
4. For day-to-day recipes, load the matching family file:
   - Mail (read / send / search / attachments) → `references/mail.md`
   - Calendar (events, RSVP, free/busy) → `references/calendar.md`
   - Teams chat + channel messages → `references/teams-chat.md`
   - Online meetings, recordings, transcripts → `references/online-meetings.md`
   - Drive / OneDrive / SharePoint / Google Docs export → `references/drive.md`
   - Contacts / People / directory → `references/contacts.md`
   - Delta syncs + Graph $batch + Gmail history → `references/delta-and-batch.md`
   - GitHub (PRs, issues, reviews, Actions, releases) → `references/github.md`
   - Morning Brief (headline flow — aggregates across families) → `references/morning-brief.md`

## Self-check

Before trusting the skill's routing, validate its format integrity:

    sh tests/all.sh

Runs:
  - tests/validate-recipes.sh     recipe format + cross-references
  - tests/install-test.sh          install/uninstall idempotency
  - tests/sha-banner-check.sh      sync banners point at real apl commits

Zero-exit means the catalogue is internally consistent and installable.

## Families at a glance

| Family | Providers | Reference |
|---|---|---|
| Mail | Google (Gmail) + Microsoft (Graph Mail) | `references/mail.md` |
| Calendar | Google + Microsoft | `references/calendar.md` |
| Teams chat / channels | Microsoft only | `references/teams-chat.md` |
| Online meetings (recordings, transcripts) | Microsoft only | `references/online-meetings.md` |
| Drive / OneDrive / SharePoint | both (per provider) | `references/drive.md` |
| Contacts / People / directory | both (per provider) | `references/contacts.md` |
| Delta + batch | both | `references/delta-and-batch.md` |
| GitHub (PRs, issues, Actions, releases) | GitHub via `gh` | `references/github.md` |
| Morning Brief (headline, aggregates) | all families | `references/morning-brief.md` |
