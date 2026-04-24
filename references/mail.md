<!--
  Generated from docs/specs/spec-recipes.md @ d928041
  Keep in sync manually. On recipe churn, regenerate this section.
-->

# Mail — recipes

Covers Microsoft Graph Mail (`ms:<handle>`) and Gmail (`google:<handle>`).

Abbreviations used throughout:
- `$GRAPH` = `https://graph.microsoft.com/v1.0`
- `$GMAIL` = `https://gmail.googleapis.com/gmail/v1/users/me`

In bash, literal `$` in OData query params (`$top`, `$filter`, `$select`,
`$search`, `$orderby`, `$value`) must be escaped as `\$` inside double-quoted
URLs.

**User-visible formatting (family default):**
- For message lists, show: index, `from.name <from.email>`, subject, received
  date (local time), short body preview.
- For single messages, show: from, to, cc, subject, date, then the body
  (plain text if available, else HTML-stripped).
- For send/reply/forward actions, confirm with the message id.

---

## Mail — read (Microsoft + Gmail)

### MAIL-R-1: Recent messages (Microsoft)

**When to use:** "what's in my inbox", "recent email", "latest mail".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/messages?\$top=10&\$orderby=receivedDateTime%20desc&\$select=subject,from,receivedDateTime,bodyPreview"
```

**Expected response (short):** `{ value: [{id, subject, from, receivedDateTime, bodyPreview}, ...] }` (200).

**Common errors:**
- 403 scope missing → `apl login ms:<label> --force --scope Mail.Read`
- 401 → re-run; if persistent, `apl login ms:<label> --force`

**User-visible formatting:** Numbered list of 10 messages with sender name, subject, received date, one-line preview.

### MAIL-R-2: Unread inbox (Microsoft)

**When to use:** "show unread emails", "unread in my inbox".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/mailFolders/inbox/messages?\$filter=isRead%20eq%20false&\$top=20&\$select=subject,from,receivedDateTime"
```

**Expected response:** `{ value: [...] }` filtered to unread.

**Common errors:** 403 Mail.Read scope → same remediation as MAIL-R-1.

**User-visible formatting:** "N unread:" + list of subject + from.

### MAIL-R-3: Unread count only (Microsoft)

**When to use:** "how many unread", "badge number".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/mailFolders/inbox?\$select=unreadItemCount,totalItemCount"
```

**Expected response:** `{ unreadItemCount: N, totalItemCount: M }`.

**User-visible formatting:** "You have N unread of M total in inbox."

### MAIL-R-4: Today's inbox (Microsoft)

**When to use:** "email since midnight", "today's inbox".

**Command (macOS/BSD date):**
```bash
apl call ms:<label> GET "$GRAPH/me/messages?\$filter=receivedDateTime%20ge%20$(date -u +%Y-%m-%dT00:00:00Z)&\$orderby=receivedDateTime%20desc"
```

On GNU Linux: use `date -u -d tomorrow` for the upper bound equivalent.

**Expected response:** Today's messages.

**Common errors:** None specific; malformed date → 400.

**User-visible formatting:** List, grouped by sender if many.

### MAIL-R-5: Full-text search (Microsoft)

**When to use:** "search my mail for 'project kickoff'".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/messages?\$search=\"project%20kickoff\"" -H 'ConsistencyLevel: eventual'
```

**Expected response:** Matching messages.

**Common errors:**
- 400 "The property 'Subject' does not support the '$search' query option" → the `ConsistencyLevel: eventual` header is missing.
- Cannot combine `$search` with `$filter` or `$orderby`.

**User-visible formatting:** List, ranked by relevance (order given).

### MAIL-R-6: Mail from specific sender (Microsoft)

**When to use:** "find emails from shaama@reqsume.com".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/messages?\$filter=from/emailAddress/address%20eq%20'shaama@reqsume.com'&\$top=20"
```

**Expected response:** Messages from that sender.

**Common errors:** Single-quote string values inside `$filter`; double quotes 400.

**User-visible formatting:** Subject + date list.

### MAIL-R-7: Emails with attachments (Microsoft)

**When to use:** "mail with attachments".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/messages?\$filter=hasAttachments%20eq%20true&\$top=20&\$select=subject,from,hasAttachments"
```

**Expected response:** Filtered list.

**User-visible formatting:** Subject + from; mention attachment count.

### MAIL-R-8: Get a single message (Microsoft)

**When to use:** "open that email", "show me the content".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/messages/{id}"
```

**Expected response:** `{ id, subject, body{contentType, content}, from, toRecipients, ... }`.

**User-visible formatting:** Headers block, then body (strip HTML if `contentType=="html"` and we're in a plain context).

### MAIL-R-9: Raw MIME / .eml (Microsoft)

**When to use:** "download the .eml", "raw source".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/messages/{id}/\$value" -o message.eml
```

**Expected response:** text/plain EML bytes to file.

**Common errors:** Forgetting `\$` escape on `$value` → 400.

**User-visible formatting:** "Saved to message.eml."

### MAIL-R-10: List attachments (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/messages/{id}/attachments"
```

**Expected response:** `{ value: [{id, name, contentType, size}, ...] }`.

**User-visible formatting:** Numbered list, show name + size.

### MAIL-R-11: Download attachment (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/messages/{id}/attachments/{aid}/\$value" -o attachment.bin
```

**Expected response:** Binary bytes to file.

**User-visible formatting:** "Saved attachment to <filename>."

### MAIL-R-12: List mail folders (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/mailFolders?\$top=50"
```

**Expected response:** `{ value: [{id, displayName, unreadItemCount}, ...] }`.

**User-visible formatting:** Folder name + unread count table.

### MAIL-R-13: Sent mail (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/mailFolders/sentItems/messages?\$top=20&\$orderby=sentDateTime%20desc"
```

**Expected response:** Sent items, newest first.

**User-visible formatting:** To + subject + sent date.

### MAIL-R-14: Drafts (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/mailFolders/drafts/messages"
```

**Expected response:** Draft messages.

**User-visible formatting:** Subject + last modified.

### MAIL-R-15: Delta sync inbox (Microsoft)

**When to use:** "what changed since last sync".

**Command (first call):**
```bash
apl call ms:<label> GET "$GRAPH/me/mailFolders/inbox/messages/delta"
```

Subsequent calls: `apl call ms:<label> GET "<saved-deltaLink>"`.

**Expected response:** Paginated; follow every `@odata.nextLink` to the final page to obtain `@odata.deltaLink`. Persist the deltaLink per (handle, folder).

**Common errors:** Stale deltaLink (>days/weeks old) may 410 → bootstrap a fresh full sync.

**User-visible formatting:** "N new, M changed, K deleted since last sync."

### MAIL-R-16: List messages (Gmail)

**Command:**
```bash
apl call google:<label> GET "$GMAIL/messages?maxResults=10"
```

**Expected response:** `{ messages: [{id, threadId}, ...], resultSizeEstimate }` — ids only.

**Common errors:** 403 → `apl login google:<label> --force --scope gmail.readonly`.

**User-visible formatting:** Note IDs are opaque — must fetch each to get headers. For user output, chain MAIL-R-22 per id (or use a single-message recipe).

### MAIL-R-17: Unread (Gmail)

**Command:**
```bash
apl call google:<label> GET "$GMAIL/messages?q=is:unread&maxResults=20"
```

**Expected response:** Ids of unread.

**User-visible formatting:** Chain MAIL-R-22 for headers, then list.

### MAIL-R-18: Today's mail (Gmail)

**Command:**
```bash
apl call google:<label> GET "$GMAIL/messages?q=in:inbox%20newer_than:1d&maxResults=50"
```

**Expected response:** Ids of today's inbox mail.

**Gmail `q=` cheatsheet:** `from:`, `to:`, `cc:`, `subject:`, `label:`, `has:attachment`, `filename:pdf`, `is:unread`, `is:starred`, `newer_than:1d`, `older_than:7d`, `before:2026/04/23`, `after:2026/04/01`, `larger:5M`, `category:primary|social|promotions|updates`, `OR`, `-`.

**User-visible formatting:** Chain metadata fetch per id; show subject + from + date.

### MAIL-R-19: From specific sender (Gmail)

**Command:**
```bash
apl call google:<label> GET "$GMAIL/messages?q=from:shaama@reqsume.com&maxResults=50"
```

**User-visible formatting:** Ids → fetch headers → render.

### MAIL-R-20: With attachments (Gmail)

**Command:**
```bash
apl call google:<label> GET "$GMAIL/messages?q=has:attachment&maxResults=50"
```

### MAIL-R-21: Full message (Gmail)

**Command:**
```bash
apl call google:<label> GET "$GMAIL/messages/{id}?format=full"
```

**Expected response:** `{ id, threadId, labelIds, payload{headers, parts}, snippet }`. Body text in `payload.parts[*].body.data` as base64url.

**User-visible formatting:** Decode base64url (`python3 -c "import base64,sys;print(base64.urlsafe_b64decode(sys.stdin.read()+'==').decode())"`), strip HTML if needed, render headers + body.

### MAIL-R-22: Headers only (Gmail)

**When to use:** Cheap rendering of a message list.

**Command:**
```bash
apl call google:<label> GET "$GMAIL/messages/{id}?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date"
```

**Common errors:** Repeat `metadataHeaders=` per header. Comma-separated does NOT work.

**User-visible formatting:** Pluck Subject/From/Date from `payload.headers[]`.

### MAIL-R-23: Raw RFC-2822 (Gmail)

**Command:**
```bash
apl call google:<label> GET "$GMAIL/messages/{id}?format=raw"
```

**Expected response:** `{ raw: "<base64url>" }`. Decode:
```
python3 -c "import base64,sys,json;print(base64.urlsafe_b64decode(json.load(sys.stdin)['raw']+'==').decode())"
```

**User-visible formatting:** "Saved raw source to message.eml" (after decoding to file).

### MAIL-R-24: Get attachment (Gmail)

**Command:**
```bash
apl call google:<label> GET "$GMAIL/messages/{msgId}/attachments/{attId}"
```

**Expected response:** `{ size, data }` where `data` is base64url.

**Common errors:** Attachment id is scoped to the message — pull from `payload.parts[*].body.attachmentId` in a prior `format=full` fetch.

**User-visible formatting:** Decode base64url to a file; confirm path + size.

### MAIL-R-25: List labels (Gmail)

**Command:**
```bash
apl call google:<label> GET "$GMAIL/labels"
```

**Expected response:** `{ labels: [{id, name, type}, ...] }`.

**User-visible formatting:** Split system vs user labels; show name + id.

### MAIL-R-26: History since ID (Gmail delta)

**Command:**
```bash
apl call google:<label> GET "$GMAIL/history?startHistoryId=<prev>"
```

**Expected response:** `{ history: [{id, messages, messagesAdded, messagesDeleted, labelsAdded, labelsRemoved}, ...], historyId }`.

**Common errors:** Expired historyId (>~7d old) returns 404 → fall back to full sync.

**User-visible formatting:** "N changes since last check."

---

## Mail — write (Microsoft + Gmail)

### MAIL-W-1: Send plain text (Microsoft)

**When to use:** "send an email to X saying Y".

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/sendMail" --body '{
  "message":{
    "subject":"apl smoke",
    "body":{"contentType":"Text","content":"hello"},
    "toRecipients":[{"emailAddress":{"address":"x@y.com"}}]
  },
  "saveToSentItems":true
}'
```

**Expected response:** 202 Accepted, empty body.

**Common errors:**
- 403 Mail.Send → `apl login ms:<label> --force --scope Mail.Send`
- 400 malformed body → ensure `message` wrapper key and `saveToSentItems` sibling.

**User-visible formatting:** "Sent." — no message id is returned by `/me/sendMail`; for an id, use MAIL-W-6 + MAIL-W-7.

### MAIL-W-2: Send with attachment (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/sendMail" --body '{
  "message":{
    "subject":"report",
    "body":{"contentType":"Text","content":"see attached"},
    "toRecipients":[{"emailAddress":{"address":"x@y.com"}}],
    "attachments":[{
      "@odata.type":"#microsoft.graph.fileAttachment",
      "name":"report.pdf",
      "contentType":"application/pdf",
      "contentBytes":"<base64-encoded-bytes>"
    }]
  }
}'
```

**Expected response:** 202.

**Common errors:**
- `contentBytes` is plain base64 (NOT base64url).
- Files >3MB → use upload session (out of v1 scope).

**User-visible formatting:** "Sent with 1 attachment."

### MAIL-W-3: Reply (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/messages/{id}/reply" --body '{"comment":"thanks"}'
```

**Expected response:** 202.

**User-visible formatting:** "Reply sent."

### MAIL-W-4: Reply all (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/messages/{id}/replyAll" --body '{"comment":"thanks all"}'
```

**Expected response:** 202.

### MAIL-W-5: Forward (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/messages/{id}/forward" --body '{
  "toRecipients":[{"emailAddress":{"address":"x@y.com"}}],
  "comment":"fyi"
}'
```

**Expected response:** 202.

### MAIL-W-6: Create draft (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/messages" --body '{
  "subject":"draft",
  "body":{"contentType":"Text","content":"wip"},
  "toRecipients":[{"emailAddress":{"address":"x@y.com"}}]
}'
```

**Expected response:** 201; draft with `id`.

**Common errors:** 403 Mail.ReadWrite → `apl login ms:<label> --force --scope Mail.ReadWrite`.

**User-visible formatting:** "Draft saved. id=<id>."

### MAIL-W-7: Send a draft (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/messages/{draftId}/send"
```

**Expected response:** 202.

### MAIL-W-8: Mark read/unread (Microsoft)

**Command:**
```bash
apl call ms:<label> PATCH "$GRAPH/me/messages/{id}" --body '{"isRead":true}'
```

**Expected response:** 200; updated message.

### MAIL-W-9: Move to folder (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/messages/{id}/move" --body '{"destinationId":"archive"}'
```

**Expected response:** 201; moved message.

**Common errors:** `destinationId` accepts well-knowns: `inbox`, `sentItems`, `drafts`, `deleteditems`, `archive`, `junkemail`. Or a specific folder id from MAIL-R-12.

### MAIL-W-10: Delete / trash (Microsoft)

**Command:**
```bash
apl call ms:<label> DELETE "$GRAPH/me/messages/{id}"
```

**Expected response:** 204.

**Common errors:** Hard-deletes if the message is already in Deleted Items. For soft-delete prefer MAIL-W-9 with `destinationId=deleteditems`.

**User-visible formatting:** Confirm destructive action before running.

### MAIL-W-11: Send (Gmail)

**Command:**
```bash
RAW=$(python3 -c "
import base64
from email.message import EmailMessage
m = EmailMessage()
m['To'] = 'x@y.com'
m['Subject'] = 'apl smoke'
m.set_content('hello')
print(base64.urlsafe_b64encode(bytes(m)).decode().rstrip('='))")
apl call google:<label> POST "$GMAIL/messages/send" --body "{\"raw\":\"$RAW\"}"
```

**Expected response:** `{ id, threadId, labelIds: ["SENT"] }`.

**Common errors:**
- 403 → `apl login google:<label> --force --scope gmail.send`
- 400 → Gmail's send takes `{"raw": <base64url RFC-2822>}`, NOT a structured JSON message.

**User-visible formatting:** "Sent. Message id: <id>."

### MAIL-W-12: Reply threaded (Gmail)

**Command:**
```bash
# Build RAW with In-Reply-To and References headers set to parent Message-ID
apl call google:<label> POST "$GMAIL/messages/send" --body "{\"raw\":\"$RAW\",\"threadId\":\"<threadId>\"}"
```

**Expected response:** 200 with matching `threadId`.

**Common errors:** `threadId` alone isn't enough — must also set `In-Reply-To` and `References` in the RFC-2822 headers or Gmail won't render the reply threaded.

### MAIL-W-13: Create draft (Gmail)

**Command:**
```bash
apl call google:<label> POST "$GMAIL/drafts" --body "{\"message\":{\"raw\":\"$RAW\"}}"
```

**Expected response:** `{ id, message: {...} }`.

### MAIL-W-14: Send draft (Gmail)

**Command:**
```bash
apl call google:<label> POST "$GMAIL/drafts/send" --body '{"id":"<draftId>"}'
```

**Expected response:** 200 with the sent message.

### MAIL-W-15: Mark read (Gmail)

**Command:**
```bash
apl call google:<label> POST "$GMAIL/messages/{id}/modify" --body '{"removeLabelIds":["UNREAD"]}'
```

**Expected response:** 200.

### MAIL-W-16: Mark unread (Gmail)

**Command:**
```bash
apl call google:<label> POST "$GMAIL/messages/{id}/modify" --body '{"addLabelIds":["UNREAD"]}'
```

### MAIL-W-17: Trash (Gmail)

**Command:**
```bash
apl call google:<label> POST "$GMAIL/messages/{id}/trash"
```

**Expected response:** 200; message with `TRASH` label added.

### MAIL-W-18: Untrash (Gmail)

**Command:**
```bash
apl call google:<label> POST "$GMAIL/messages/{id}/untrash"
```

### MAIL-W-19: Permanently delete (Gmail)

**Command:**
```bash
apl call google:<label> DELETE "$GMAIL/messages/{id}"
```

**Expected response:** 204.

**User-visible formatting:** "This is irreversible. Confirm?" before running.

### MAIL-W-20: Create label (Gmail)

**Command:**
```bash
apl call google:<label> POST "$GMAIL/labels" --body '{
  "name":"Project/X",
  "messageListVisibility":"show",
  "labelListVisibility":"labelShow"
}'
```

**Expected response:** `{ id: "Label_123", name, ... }`.

**User-visible formatting:** Nested names with `/` render as nested labels.

### MAIL-W-21: Apply label (Gmail)

**Command:**
```bash
apl call google:<label> POST "$GMAIL/messages/{id}/modify" --body '{"addLabelIds":["Label_123"]}'
```

### MAIL-W-22: Remove label (Gmail)

**Command:**
```bash
apl call google:<label> POST "$GMAIL/messages/{id}/modify" --body '{"removeLabelIds":["Label_123"]}'
```
