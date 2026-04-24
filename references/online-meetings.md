<!--
  Generated from docs/specs/spec-recipes.md @ d928041
  Keep in sync manually. On recipe churn, regenerate this section.
-->

# Online meetings — recipes

Microsoft-only. Includes the known platform walls around meeting recordings
(SharePoint ACL, non-organizer access).

Abbreviation:
- `$GRAPH` = `https://graph.microsoft.com/v1.0`

**User-visible formatting (family default):**
- Meeting metadata: subject, time, organizer, chatInfo.threadId (so the user
  can jump to meeting chat).
- Recordings: list as `<filename> · <size> · <createdDateTime>`.
- Transcripts: confirm path after download + file size.
- On 403 walls: surface the documented workaround. Do not fake success.
  For recording-binary 403s specifically, follow the share-link retry
  pattern under MEET-9 — that path is user-action-required, not terminal.

---

### MEET-1: List online meetings in calendar (Microsoft)

See `calendar.md` → CAL-R-4. Same recipe, filters calendar events for
`isOnlineMeeting=true`.

### MEET-2: Resolve meeting by joinWebUrl (Microsoft)

**When to use:** Have a Teams join link, need the `onlineMeeting` object.

**Command:**
```bash
ENC=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "<joinUrl>")
apl call ms:<label> GET "$GRAPH/me/onlineMeetings?\$filter=JoinWebUrl%20eq%20'$ENC'"
```

**Expected response:** `{ value: [{id, joinWebUrl, chatInfo, participants, ...}] }`.

**Common errors:**
- Only `JoinWebUrl` and `VideoTeleconferenceId` are supported `$filter` fields. `contains`, `startswith` silently fail or 400.
- You cannot list all meetings — always lookup by join URL.
- 403 → `apl login ms:<label> --force --scope OnlineMeetings.Read`.

### MEET-3: Get meeting metadata (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/onlineMeetings/{meetingId}"
```

### MEET-4: Meeting chat id via chatInfo.threadId (Microsoft)

**When to use:** Find the chat thread attached to a meeting (to read messages, find shared links, find the recording via chat iteration).

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/onlineMeetings/{meetingId}?\$select=chatInfo"
```

**Expected response:** `{ chatInfo: { threadId: "19:meeting_...@thread.v2", ... } }`.

**User-visible formatting:** Use `threadId` as chatId for `teams-chat.md` → CHAT-5.

### MEET-5: List recordings metadata (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/onlineMeetings/{meetingId}/recordings"
```

**Expected response:** `{ value: [{id, createdDateTime, meetingOrganizer, recordingContentUrl}, ...] }`.

**Common errors:**
- 403 → scope `OnlineMeetingRecording.Read.All` requires admin consent. If unavailable, fall back to MEET-10 (chat-iteration).
- `recordingContentUrl` is NOT a direct download link — feed it to MEET-8.

### MEET-6: List transcripts metadata (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/onlineMeetings/{meetingId}/transcripts"
```

**Common errors:** 403 → `OnlineMeetingTranscript.Read.All` needs admin consent.

### MEET-7: Download transcript as VTT (Microsoft)

**When to use:** "get the transcript of last week's team meeting".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/onlineMeetings/{meetingId}/transcripts/{transcriptId}/content?\$format=text/vtt" -o transcript.vtt
```

**Expected response:** 200 text/vtt body (~93 KB for 90-min meeting).

**Common errors:** Default format is IMDN — always pass `$format=text/vtt` for speaker-tagged output.

**User-visible formatting:** "Saved transcript.vtt (<size> KB)."

### MEET-8: Download recording via `/content` (Microsoft, fragile)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/onlineMeetings/{meetingId}/recordings/{recordingId}/content" -o recording.mp4
```

**Expected response:** 200 mp4 bytes — **for the organizer only**.

**Common errors (WALL):**
- **403 `accessDenied` for non-organizers, even with full admin-consented scopes.** Graph gates this endpoint on meeting-participant ACL, NOT just scope.
- Remediation: fall back to MEET-9 (organizer's OneDrive) or MEET-10 (chat iteration).

**User-visible formatting on 403:** "This endpoint only works for the meeting organizer. Falling back to the organizer's OneDrive path (MEET-9)…"

### MEET-9: Download recording via organizer's OneDrive (Microsoft, preferred)

**When to use:** Non-organizer needs the mp4.

**Steps:**
```bash
# Step 1 — list the Recordings folder in the organizer's drive:
apl call ms:<label> GET "$GRAPH/users/{organizerUpn}/drive/root:/Recordings:/children?\$select=name,id,size,webUrl,@microsoft.graph.downloadUrl"

# Step 2 — pick the item (or fetch directly if filename is known):
apl call ms:<label> GET "$GRAPH/users/{organizerUpn}/drive/root:/Recordings/<url-encoded-filename>"
# Extract @microsoft.graph.downloadUrl from the response.
```

**Step 3 — REQUIRED fallback (MUST use curl without Authorization header):**
```bash
TOKEN=$(apl login ms:<label>)
DOWNLOAD_URL=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$GRAPH/users/{organizerUpn}/drive/root:/Recordings/<file>" \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)["@microsoft.graph.downloadUrl"])')
curl -L -o recording.mp4 "$DOWNLOAD_URL"   # NO -H Authorization
```

**Expected response:** 200 mp4 bytes.

**Common errors (WALLS):**
- `@microsoft.graph.downloadUrl` is time-limited (~1h) and carries `tempauth=` — SharePoint rejects the request if you send `Authorization: Bearer` alongside.
- Even with `Files.Read.All` + `Sites.Read.All` + admin consent, **non-organizers can 403 at Step 3** if the recording hasn't been explicitly shared with them. Teams doesn't reliably auto-share with participants.
- Remediation: ask the organizer to share via Teams Recording chat → Share, or use MEET-10.

**User-visible formatting on 403 at Step 3:** Use the share-link retry pattern below — do NOT tell the user this is impossible.

#### Recording binary download — share-link retry pattern

A 403 on the mp4 download (either via `/users/{upn}/drive/root:/Recordings/...`
or via `/shares/{encoded}/driveItem`) is a **user-action-required** failure,
not a hard wall. The recording lives in the organizer's OneDrive and simply
hasn't been ACL'd to the caller yet. Once the user clicks Share in the
stream player, the same Graph call returns 200. Follow this flow:

1. **Resolve the `callRecordingUrl`** — iterate the meeting chat (see MEET-10
   Steps) and extract `eventDetail.callRecordingUrl` from the
   `callRecordingEventMessageDetail` system message. This is the stream.aspx
   URL the user needs to open in their browser.

2. **On 403 from the mp4 download**, surface this message verbatim
   (substitute `<organizer>`, `<callRecordingUrl>`, `<active-account-upn>`):

   ```
   I can't download this recording directly — it lives in <organizer>'s
   OneDrive and hasn't been shared with you yet.

   Please:
     1. Open this URL in your browser:
        <callRecordingUrl from the chat eventDetail>
     2. Click the "Share" button (top-right of the stream player).
     3. Share with yourself (<active-account-upn>) or "Anyone with the link"
        — read access is enough.

   Say "retry" or "done" once you've shared, and I'll try the download again.
   ```

3. **On user confirmation** (`retry` / `done` / `shared` / `ok` / `go`),
   re-run the same `/users/{upn}/drive/root:/Recordings/<file>` call
   (MEET-9 Step 2 → Step 3). If the share was granted, it now returns 200
   and the `@microsoft.graph.downloadUrl` is fetchable.

4. **If still 403** on first retry, repeat the request once more. If the
   second retry is still 403, tell the user the share hasn't propagated yet
   and suggest waiting ~30 seconds before another retry. Do not give up —
   the share always works once ACL replication catches up.

**Never tell the user this is impossible on this path.** It's a latency +
human-action gap, not a permission wall.

### MEET-10: Download recording via chat iteration (Microsoft, discovery)

**When to use:** Only the meeting id is known; no organizer permission.

**Steps:**
```bash
apl call ms:<label> GET "$GRAPH/chats/{chatId}/messages?\$top=50"
```

Client-side:
- Scan for `messageType == "systemEventMessage"` AND
  `eventDetail.@odata.type == "#microsoft.graph.callRecordingEventMessageDetail"`.
- Extract `eventDetail.callRecordingUrl`.
- Parse the `id=` query param of `callRecordingUrl` to reconstruct a drive-item path like `/users/{upn}/drive/root:/Recordings/<file>.mp4`.
- Then proceed with MEET-9 Steps 2 & 3.

**Expected response:** 200 followed by the resolved drive-item fetch.

**Common errors:** `OnlineMeetingRecording.Read.All` is NOT required on this path — the chat-message path bypasses the meeting-recording authorization gate. Still needs `Chat.Read` + `Files.Read.All`.

### MEET-11: Create ad-hoc online meeting (Microsoft)

**When to use:** Provision a Teams meeting without a calendar event.

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/onlineMeetings" --body '{
  "subject":"Quick sync",
  "startDateTime":"2026-05-01T09:00:00Z",
  "endDateTime":"2026-05-01T09:30:00Z"
}'
```

**Expected response:** 201; `{ id, joinWebUrl, ... }`.

**Common errors:** 403 → `apl login ms:<label> --force --scope OnlineMeetings.ReadWrite`.

**User-visible formatting:** "Meeting ready. Join: <joinWebUrl>."

### MEET-12: Known 403 wall (reference, not an API call)

A `403 accessDenied` on MEET-8 or MEET-9 Step 3 means the recording has not
been shared with the caller. Remediation paths:

1. **Ask the organizer to share** via the Teams Recording chat → Share button.
2. **Run with admin-consented app-only `Files.Read.All` Role** — out of v1
   scope; requires a separate registration the user cannot do from the
   skill.
3. **Use MEET-10** (chat iteration) — this path bypasses the recording ACL
   gate *if* the user is a member of the meeting chat.

For MEET-8 (organizer-only endpoint) a 403 is terminal — fall back to MEET-9.
For MEET-9 Step 3, a 403 is **not** terminal: follow the share-link retry
pattern documented under MEET-9 (surface the stream.aspx URL, wait for user
confirmation, re-run the call). Do NOT tell the user the download is
impossible on the MEET-9 path.
