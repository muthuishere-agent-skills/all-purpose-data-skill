---
name: all-purpose-data-skill
description: >
  Email, calendar, Teams chat, online meetings (recordings + transcripts),
  Drive / OneDrive / SharePoint files, and contacts across Google Workspace
  and Microsoft 365. Uses `apl` (`npm install -g @muthuishere/apl`) as the
  OAuth token broker. Trigger on: send/read/reply/forward/search email,
  unread mail, today's / this week's / next meeting, create / decline /
  RSVP event, free-busy, meeting recording + transcript, search teams
  chat, dm on teams, post in channel, react, search drive / onedrive /
  sharepoint, download or export file, share file, look up contact,
  find person in directory, sync since last check, batch calls. Works
  across google:<label> and ms:<label> handles from `apl accounts`.
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
- **Ask for a handle once per session.** On the first productivity intent,
  run `apl accounts --json`, present the options grouped by provider, and
  cache the choice in conversation context. No re-prompting unless the user
  asks to switch.
- **Silent auto-switch for single compatible handle.** If the intent is
  Microsoft-only (Teams, online meetings) and the active handle is `ms:*`,
  proceed. If there is exactly one compatible handle that differs from the
  active one, auto-switch for this request and tell the user briefly.
  Ask when zero or two+ compatible handles exist.
- **Surface walls honestly.** A 403 driven by tenant policy or SharePoint ACL
  (e.g. Teams recording `/content` endpoint, DLP block, admin-consent
  required) is NOT retried. Report the wall, cite the documented workaround
  from the relevant reference, and stop.

## Session Context

The active selection is held in conversation context only — no file writes.

```
active_handle: google:work     # or ms:volentis, etc.
active_provider: google        # google | ms
```

If the session ends, the skill re-prompts next time.

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
