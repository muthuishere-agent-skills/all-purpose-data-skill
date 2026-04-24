<!-- Generated from docs/specs/spec-recipes.md @ 11d9246 -->

# Morning Brief — recipes

## What is a brief?

Morning Brief is this skill's **headline demo**. It aggregates across mail,
calendar, Teams chat, and GitHub in a single conversational turn and returns a
short, scannable summary of "what's on today".

**No new API calls.** Every bullet in a brief composes an existing recipe from
another reference file — `mail.md`, `calendar.md`, `teams-chat.md`,
`github.md`. The work in this file is *orchestration + synthesis*, not new
surface area.

**State.** Briefs read `since_last_brief` from `project.state.yaml` (see
`workflow.md` → State model) to compute delta-style sections (new Teams
messages, new PRs since last check). On exit, the skill writes back the current
timestamp so the next brief's "since" window is correct.

**Parallelism.** The sub-calls in each brief are read-only and independent.
Run them concurrently (shell `&` + `wait`, or a single agent turn with
parallel tool calls) — the brief feels fast when the slowest sub-call is the
whole wall clock.

**Output budget.** A brief is a *summary*, not a dump. Target ≤30 lines
total. If any single section has more than 5 items, show the top 3 and append
"(+N more — ask to expand)".

---

### BRIEF-1: Morning Brief (full)

**User intent:** "morning brief", "catch me up", "what's on today", "start my day".

**Sequence (parallel where safe):**
1. Today's events — `calendar.md` CAL-R-1 (Microsoft) and/or CAL-R-7 (Google), whichever handles are active.
2. Unread mail — `mail.md` MAIL-R-2 (Microsoft) and/or MAIL-R-17 (Gmail).
3. New Teams messages since last brief — `teams-chat.md` CHAT-7 (preview delta across all chats) with `$filter=lastModifiedDateTime ge <since_last_brief>`.
4. PRs assigned to me — `github.md` GH-5.
5. PRs requesting my review — `github.md` GH-6.
6. Issues assigned to me — `github.md` GH-16.

**State dependency:** reads `project.state.yaml` → `since_last_brief`; writes it back to `now()` on exit.

**Synthesis:**
- Lead with **meetings** (most time-sensitive). Show next 3; flag the next one that starts within 30 min.
- Then **queue items**: PRs to review, PRs I'm blocking, issues assigned. Sort by age; flag anything >3 days.
- Then **communications**: unread mail count + top 3 subjects; new Teams thread count + top 3 chats.
- End with "Next brief ready in N hours" if `brief_cadence` is set, else nothing.
- Keep total under 30 lines. Expand any section on user ask.

**Common errors:**
- No handles configured → route to `setup-google.md` / `setup-microsoft.md`.
- `gh` not on PATH or `gh auth status` fails → "Run `gh auth login` to include GitHub in your brief." Continue the brief without the GitHub sections.
- 401 on any sub-call → `apl login <handle> --force`, continue with partial brief, flag the skipped section.
- `since_last_brief` missing → default to "24h ago" and confirm with the user on first run.

---

### BRIEF-2: Meetings-only brief

**User intent:** "what meetings do I have", "what's on my calendar today", "meetings today".

**Sequence:**
1. Today's events — `calendar.md` CAL-R-1 (ms) + CAL-R-7 (google).

**State dependency:** none.

**Synthesis:**
- Group by provider if both handles configured; otherwise single list.
- For each event: time · title · location-or-Teams/Meet-link · attendees count.
- Flag conflicts (overlapping events) with a ⚠ marker.
- Summary line: "N meetings today, M with video links."

**Common errors:**
- No calendar scope → `apl login <handle> --force --scope Calendars.Read` / `calendar.readonly`.

---

### BRIEF-3: Queue brief (PRs + issues)

**User intent:** "pr status", "my queue", "what do I owe", "review queue".

**Sequence (parallel):**
1. PRs assigned to me — `github.md` GH-5.
2. PRs requesting my review — `github.md` GH-6.
3. My open authored PRs — `github.md` GH-7.
4. Issues assigned to me — `github.md` GH-16.

**State dependency:** optional — reads `gh_default_repo` if the user previously scoped "my queue" to a single repo.

**Synthesis:**
- Three buckets: **to review** (GH-6), **mine, blocked** (GH-7 with failing checks or requested changes), **mine, moving** (GH-7 approved or passing).
- Show repo · `#num` · title · age.
- Flag stale (>7 days) with ⏳.

**Common errors:**
- `gh` not installed → see install-time warning; cannot run this brief.
- `gh auth status` reports expired → "Run `gh auth login` and retry."

---

### BRIEF-4: Inbox brief

**User intent:** "email brief", "what's in my inbox", "mail summary".

**Sequence (parallel across active handles):**
1. Unread count — `mail.md` MAIL-R-3 (ms) for ms handles.
2. Unread list, top 10 — `mail.md` MAIL-R-2 (ms) or MAIL-R-17 + MAIL-R-22 (gmail).

**State dependency:** none.

**Synthesis:**
- Per handle: "N unread in <handle>" then top 10 as subject + from + age.
- Group by sender when one sender dominates (>3 of 10).

**Common errors:**
- Scope missing → `apl login <handle> --force --scope Mail.Read` / `gmail.readonly`.

---

### BRIEF-5: Chat brief (Teams)

**User intent:** "new messages", "anything new on teams", "teams catch up".

**Sequence:**
1. New messages across chats since `since_last_brief` — `teams-chat.md` CHAT-7 (preview).
2. For the top 3 active chats (most messages), fetch recent messages — `teams-chat.md` CHAT-5.

**State dependency:** reads + writes `since_last_brief` (or dedicated `since_last_chat_brief` if set).

**Synthesis:**
- "N new messages across M chats since <since>."
- Top 3 chats: chat topic · sender(s) · last message preview.

**Common errors:**
- `google:*` active → auto-switch to `ms:*` per workflow.md compatibility gate (Teams is Microsoft-only). If no `ms:*` handle, skip this section and tell user.

---

### BRIEF-6: GitHub-only brief

**User intent:** "github brief", "gh status", "catch me up on code".

**Sequence (parallel):**
1. PRs requesting my review — `github.md` GH-6.
2. PRs assigned to me — `github.md` GH-5.
3. My authored PRs — `github.md` GH-7.
4. Issues assigned to me — `github.md` GH-16.
5. Recent CI runs on `gh_default_repo` — `github.md` GH-27.

**State dependency:** reads `gh_default_repo` from `project.state.yaml`; if unset, falls back to `gh repo view --json nameWithOwner -q .nameWithOwner` per handle-selection.md.

**Synthesis:**
- Four sections as above. Append a "CI" line: "N recent runs, K failing."

**Common errors:**
- `gh` not installed / not authed → see BRIEF-3.
- `gh_default_repo` unresolved → prompt once, cache, retry.

---

### BRIEF-7: End-of-day brief

**User intent:** "wrap up", "end of day", "what did I get done today", "eod summary".

**Sequence (parallel):**
1. Events that actually occurred today — `calendar.md` CAL-R-1 filtered to past.
2. Mail sent today — `mail.md` MAIL-R-13 (ms sent items filter: today) + Gmail `q=in:sent newer_than:1d` via MAIL-R-16/MAIL-R-22.
3. PRs I merged today — `github.md` GH-37 with `search prs is:merged author:@me merged:>=<today>`.
4. Issues I closed today — `github.md` GH-37 adapted for issues (`gh search issues closed:>=<today> assignee:@me state:closed`).

**State dependency:** none — computes "today" from local date.

**Synthesis:**
- "Here's what you did today:" then 4 bullets: meetings attended, mails sent, PRs merged, issues closed.
- One-line totals per bucket.

**Common errors:**
- Gmail sent-items requires `gmail.readonly`.

---

### BRIEF-8: Custom brief (composable)

**User intent:** "brief me on <X>", "just mail and calendar", "skip github today".

**Sequence:** the agent parses which of {meetings, mail, chat, github} the user asked for, then runs the corresponding subset of BRIEF-1's sub-recipes in parallel.

**State dependency:** same as BRIEF-1 for whatever sections are included.

**Synthesis:** Same structure as BRIEF-1, minus skipped sections.

**Common errors:**
- Ambiguous phrasing ("brief me on work") → ask once which sections the user wants; cache the answer for the session under `preferred_brief_sections`.
