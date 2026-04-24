---
name: all-purpose-data-skill
---

# Workflow — top-level routing

This is the decision graph the agent follows on every productivity intent.

## Variables

- `{skill-root}` — installed root folder of this skill.
- `{active_handle}` — handle chosen for this session (e.g. `ms:volentis`). In
  conversation context only; never written to disk.
- `{active_provider}` — `google` | `ms`, derived from the handle prefix.

## Preflight (run once per session, before any other call)

1. `command -v apl` — is apl on PATH?
2. `apl version` — must exit 0.
3. If either step fails, respond:

   > `apl` is not installed. Install it with: `npm install -g @muthuishere/apl`, then try again.

   Do not attempt any further `apl …` calls this turn.

## Handle selection (first productivity intent only)

1. Run `apl accounts --json`.
2. Parse the array. If empty → route to setup (see "Setup routing" below).
3. If non-empty, follow `references/handle-selection.md` for the picker and
   auto-pick rules.
4. Cache `{active_handle}` + `{active_provider}` in context.
5. Later intents reuse the cache without re-prompting.

If the user says "switch account" / "use X instead" / "change to my personal
gmail" / "use volentis" → re-run `apl accounts --json`, re-prompt, replace
context.

## Intent classification

Map the user's phrase to a recipe family. Then load the matching reference.

| Phrase contains | Family | Reference |
|---|---|---|
| email, mail, inbox, gmail, reply, forward, draft | Mail | `mail.md` |
| calendar, meeting (with time), event, schedule, RSVP, free/busy, today's, this week | Calendar | `calendar.md` |
| teams message, channel, dm on teams, react, post in | Teams chat | `teams-chat.md` |
| recording, transcript, meeting chat history, who attended, online meeting | Online meetings | `online-meetings.md` |
| drive, onedrive, sharepoint, file, pdf, document, export, download, upload | Drive / files | `drive.md` |
| contact, people, directory, who is, look up person | Contacts | `contacts.md` |
| delta, changes since, sync, batch, $batch | Delta + batch | `delta-and-batch.md` |

If the phrase straddles two families (e.g. "send an email with the recording
from yesterday's meeting"), handle them sequentially — fetch the recording
link via `online-meetings.md`, then compose mail via `mail.md`.

## Provider compatibility gate

Before issuing the call, check that `{active_provider}` can serve the intent.

- **Microsoft-only intents:** Teams chat, Teams channel messages, online
  meetings (recordings, transcripts, meeting metadata), SharePoint sites,
  OneDrive, Presence, directory (`$GRAPH/users`).
- **Google-only intents:** Google Docs / Sheets / Slides **export**, Gmail
  labels, Google Drive native file operations, Google People directory.
- **Mirror (either works, per-provider recipe):** Mail read/send, calendar
  events, contacts (Google People / Graph Contacts), Drive (Google
  Drive / OneDrive — but the recipe is provider-specific).

If `{active_provider}` is incompatible:

1. Re-scan `apl accounts --json` for compatible handles.
2. If **exactly one** compatible handle exists → auto-switch for this call.
   Tell the user: *"Switched to `{new_handle}` for this (Teams is Microsoft-only)."*
   Update context.
3. If **zero** compatible handles → tell the user what's needed and point at
   `setup-google.md` or `setup-microsoft.md`.
4. If **two or more** compatible handles → ask which to use.

## Executing a recipe

1. Open the family reference.
2. Find the matching intent subsection (`MAIL-W-1`, `CAL-R-7`, etc.).
3. Substitute variables: `<handle>` → `{active_handle}`, IDs from prior listing
   calls, the user's free-text arguments (recipient, subject, etc.).
4. Run the documented `apl call …` command verbatim.
5. Capture stdout (JSON or binary).
6. Render per the recipe's "User-visible formatting" block.

## Failure handling

| HTTP | Class | Action |
|---|---|---|
| 2xx | Success | Render per recipe. |
| 3xx | Redirect | `apl call` follows automatically. For pre-authenticated SharePoint URLs the recipe explicitly uses the curl fallback. |
| 401 | Token rejected | `apl call` auto-refreshes once. If still 401, run `apl login {active_handle} --force` and re-run the call. |
| 403 insufficient scope | Provider mentions scope name | Run `apl login {active_handle} --force --scope <scope>` with the scope named in the recipe's "Scopes" line, then retry once. |
| 403 tenant policy / ACL | Provider message mentions `accessDenied`, `resourceNotFound` on a recording, DLP quarantine, or `Forbidden` on a SharePoint item | Surface the wall honestly. Cite the recipe's documented workaround. Stop. |
| 403 on meeting-recording content (MEET-9 Step 3 / `/users/{upn}/drive/root:/Recordings/...` / `/shares/{encoded}/driveItem`) | `accessDenied` on the mp4 bytes | **User-action-required, not a hard failure.** Follow the share-link retry pattern in `online-meetings.md` under MEET-9 ("Recording binary download — share-link retry pattern"): surface the `callRecordingUrl` from the chat eventDetail, ask the user to click Share in the stream player, then re-run the same call on their confirmation. |
| 404 | Target not found | Return the provider message verbatim. Suggest the relevant listing recipe to re-discover the id. |
| 429 | Rate limited | Respect `Retry-After`; back off once. If second call also 429, surface to user with the header value. |
| 5xx | Provider outage | Retry once with small jitter. If still failing, report and stop. |

`apl call` exit codes (per `spec-apl-call.md`):
- 0 = HTTP 2xx
- 1 = user error or client-built 4xx
- 2 = auth error (no record, missing scope, 401 after retry)
- 3 = network error
- 4 = HTTP 429
- 5 = HTTP 5xx

## Conventions

- Always show the exact `apl call …` command in a code fence before running it
  (the user can copy-paste to verify).
- For listings, cap at the first ~20 entries by default; ask if the user wants
  more / paginated output.
- For destructive writes (delete mail, cancel event, delete file, hard-delete),
  show the command and ask for explicit confirmation before running.
- Never echo an access token in any form — not in a code fence, not in a
  narrative sentence.
