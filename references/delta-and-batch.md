<!--
  Generated from docs/specs/spec-recipes.md @ d928041
  Keep in sync manually. On recipe churn, regenerate this section.
-->

# Delta sync + batch — recipes

Incremental syncs across Gmail, Google Calendar, Google Drive, Microsoft
Mail, Microsoft Events, OneDrive, Teams chats, and the directory — plus
batch request patterns (`$batch`, Gmail multipart batch) and webhook
subscriptions.

Abbreviations:
- `$GRAPH` = `https://graph.microsoft.com/v1.0`
- `$GMAIL` = `https://gmail.googleapis.com/gmail/v1/users/me`
- `$CAL` = `https://www.googleapis.com/calendar/v3`
- `$DRIVE` = `https://www.googleapis.com/drive/v3`

**User-visible formatting (family default):**
- Deltas: "N new, M changed, K deleted since last sync." Offer to persist
  the deltaLink / syncToken / startPageToken for next time.
- Batch: "N subrequests, M succeeded, K failed." For failed ones, list
  the subrequest id + provider error.
- Subscriptions: confirm id + expiration; remind the user to renew before
  expiry.

---

## Delta recipes

### SYNC-1: Gmail history since ID

Alias of MAIL-R-26. See `mail.md`.

```bash
apl call google:<label> GET "$GMAIL/history?startHistoryId=<prev>"
```

**Common errors:** Expired historyId (>~7d old) 404s → full resync.

### SYNC-2: Google Calendar syncToken

**First call** captures `nextSyncToken`:
```bash
apl call google:<label> GET "$CAL/calendars/primary/events?maxResults=250&singleEvents=true&showDeleted=true"
```

**Subsequent:**
```bash
apl call google:<label> GET "$CAL/calendars/primary/events?syncToken=<saved>"
```

**Common errors:**
- `410 GONE` → syncToken expired. Bootstrap a fresh full sync.
- `showDeleted=true` is required on subsequent calls to see cancellations.

### SYNC-3: Microsoft Mail delta

Alias of MAIL-R-15. See `mail.md`.

```bash
apl call ms:<label> GET "$GRAPH/me/mailFolders/inbox/messages/delta"
```

### SYNC-4: Microsoft Events delta

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/calendarView/delta?startDateTime=2026-01-01T00:00:00Z&endDateTime=2026-12-31T00:00:00Z"
# Subsequent: GET <saved @odata.deltaLink>
```

**Expected response:** Paginated. Follow `@odata.nextLink` to completion; persist `@odata.deltaLink` from the last page.

### SYNC-5: Google Drive changes feed

Alias of DRIVE-27. See `drive.md`.

```bash
apl call google:<label> GET "$DRIVE/changes/startPageToken"
apl call google:<label> GET "$DRIVE/changes?pageToken=<token>"
```

### SYNC-6: OneDrive delta

Alias of DRIVE-11. See `drive.md`.

```bash
apl call ms:<label> GET "$GRAPH/me/drive/root/delta"
```

### SYNC-7: Directory users delta (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/users/delta?\$select=displayName,mail,jobTitle"
```

**Common errors:** 403 → `apl login ms:<label> --force --scope User.Read.All` (admin consent).

---

## Batch + webhook recipes

### ADV-1: Microsoft Graph $batch

**When to use:** Up to 20 Graph sub-requests in a single POST.

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/\$batch" --body '{
  "requests":[
    {"id":"1","method":"GET","url":"/me"},
    {"id":"2","method":"GET","url":"/me/messages?$top=5&$select=subject"},
    {"id":"3","method":"GET","url":"/me/calendarView?startDateTime=2026-04-23T00:00:00Z&endDateTime=2026-04-24T00:00:00Z"}
  ]
}'
```

**Expected response:** `{ responses: [{id, status, body}, ...] }` keyed by your sub-request ids.

**Common errors:**
- Sub-request URLs are relative to `/v1.0` — do NOT include host or `/v1.0` prefix.
- Max 20 per batch.
- Scopes: union of all sub-request scopes. Missing any → 403 on that sub-request only.

**User-visible formatting:** Render per-subrequest status next to the user's original intents.

### ADV-2: Gmail batch (Google multipart) — FALLBACK

**Fallback:** `apl call` does not construct multipart/mixed bodies. Use curl:
```bash
TOKEN=$(apl login google:<label>)
curl -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: multipart/mixed; boundary=batch_apl" \
  --data-binary @batch.body \
  -X POST "https://www.googleapis.com/batch/gmail/v1"
```

`batch.body` is an RFC-1341 multipart document where each part is a full HTTP request with its own headers.

**Expected response:** 200 multipart response, one part per subrequest.

**Common errors:** Google also exposes `batch/calendar/v3` and `batch/drive/v3` — same format.

### ADV-3: Graph webhook subscription (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/subscriptions" --body '{
  "changeType":"created,updated",
  "notificationUrl":"https://your-endpoint.example.com/graph",
  "resource":"me/mailFolders/inbox/messages",
  "expirationDateTime":"2026-05-01T00:00:00Z",
  "clientState":"secret-nonce"
}'
```

**Expected response:** 201; `{ id, expirationDateTime, resource, ... }`.

**Common errors:**
- Graph does a validation handshake: your `notificationUrl` must be publicly reachable and echo `validationToken` query param within 10 seconds.
- Max expiration varies by resource (1h for chat messages, 3 days for mail). Renew with PATCH before expiry.
- Scope depends on resource (e.g. `Mail.Read` for `me/mailFolders/inbox/messages`).

**User-visible formatting:** "Subscription created: id=<id>, expires <dt>. Renew before expiry."

### ADV-4: Gmail watch (push via Pub/Sub)

**Command:**
```bash
apl call google:<label> POST "$GMAIL/watch" --body '{
  "topicName":"projects/<gcp-project>/topics/gmail",
  "labelIds":["INBOX"]
}'
```

**Expected response:** `{ historyId, expiration }`.

**Common errors:** Pub/Sub topic must grant `gmail-api-push@system.gserviceaccount.com` the Pub/Sub Publisher role. Watch expires after 7 days — renew on cadence.

### ADV-5: Google Calendar watch (webhook)

**Command:**
```bash
apl call google:<label> POST "$CAL/calendars/primary/events/watch" --body '{
  "id":"apl-channel-'$(uuidgen)'",
  "type":"web_hook",
  "address":"https://your-endpoint.example.com/calendar"
}'
```

**Expected response:** 200; channel object with `resourceId` used to stop the channel.

**Common errors:** Address must be HTTPS with a publicly-verifiable certificate. Stop channels with `POST /channels/stop`.
