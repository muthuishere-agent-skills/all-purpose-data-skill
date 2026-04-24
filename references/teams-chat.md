<!--
  Generated from docs/specs/spec-recipes.md @ d928041
  Keep in sync manually. On recipe churn, regenerate this section.
-->

# Teams chat — recipes

Microsoft-only. All recipes require `ms:<label>`. Auto-switch from any
Google handle if the user has exactly one Microsoft handle; otherwise ask.

Abbreviation:
- `$GRAPH` = `https://graph.microsoft.com/v1.0`

**User-visible formatting (family default):**
- Chat lists: chat type + topic/members, last modified time.
- Message lists: sender display name + body content (trimmed) + time.
- Channel messages: include team + channel name.
- Reaction actions: confirm action with the message id.

---

### CHAT-1: List all my chats (Microsoft)

**When to use:** "show my teams chats".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/chats?\$expand=members&\$top=50"
```

**Expected response:** `{ value: [{id, chatType, topic?, members}, ...] }`. `chatType` is `oneOnOne`, `group`, or `meeting`.

**Common errors:** 403 → `apl login ms:<label> --force --scope Chat.Read`.

**User-visible formatting:** For `oneOnOne` show the other member's name; for `group` show topic + member count; for `meeting` show subject.

### CHAT-2: Find a 1:1 chat with X (Microsoft)

**When to use:** "find my chat with X".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/chats?\$filter=chatType%20eq%20'oneOnOne'&\$expand=members"
# Client-side: match members[].email == 'x@y.com'
```

**Common errors:** No server-side filter by member email — must list and grep.

### CHAT-3: Find a group chat by topic (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/chats?\$filter=chatType%20eq%20'group'"
# Client-side: topic contains 'X'
```

### CHAT-4: Find meeting chats (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/chats?\$filter=chatType%20eq%20'meeting'"
```

**Expected response:** Chat ids like `19:meeting_...@thread.v2`.

### CHAT-5: Messages in a chat (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/chats/{chatId}/messages?\$top=50"
```

**Expected response:** `{ value: [...], @odata.nextLink? }`. System events appear as `messageType=systemEventMessage` with populated `eventDetail`.

**Common errors:** Use the top-level `/chats/{id}/messages` path — `eventDetail` is reliably populated there; it's often empty via `/me/chats/{id}/messages`.

**User-visible formatting:** For each message: from + time + body.content (strip HTML).

### CHAT-6: New messages since last poll (Microsoft delta)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/chats/{chatId}/messages/delta"
```

Persist `@odata.deltaLink` from the final page; reuse next time.

### CHAT-7: All new messages across every chat (Microsoft preview)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/chats/getAllMessages"
```

**Expected response:** Paginated feed.

**Common errors:** Preview endpoint — schema may change. Bound the window with `$filter=lastModifiedDateTime ge 2026-01-01T00:00:00Z`.

### CHAT-8: Send text to a chat (Microsoft)

**When to use:** "dm X on teams", "send a message in that chat".

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/chats/{chatId}/messages" --body '{"body":{"content":"hello"}}'
```

**Expected response:** 201; posted message object.

**Common errors:** 403 → `apl login ms:<label> --force --scope ChatMessage.Send`.

**User-visible formatting:** "Sent. Message id: <id>."

### CHAT-9: Send HTML to a chat (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/chats/{chatId}/messages" --body '{
  "body":{"contentType":"html","content":"<b>deploy</b> finished"}
}'
```

### CHAT-10: React to a message (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/chats/{cid}/messages/{mid}/setReaction" --body '{"reactionType":"like"}'
```

**Expected response:** 204.

**Common errors:** Valid `reactionType`: `like`, `heart`, `laugh`, `surprised`, `sad`, `angry`.

### CHAT-11: Remove reaction (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/chats/{cid}/messages/{mid}/unsetReaction" --body '{"reactionType":"like"}'
```

### CHAT-12: Reply to a message (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/chats/{cid}/messages/{mid}/replies" --body '{"body":{"content":"acknowledged"}}'
```

**Expected response:** 201.

### CHAT-13: Edit a message (Microsoft)

**Command:**
```bash
apl call ms:<label> PATCH "$GRAPH/chats/{cid}/messages/{mid}" --body '{"body":{"content":"edited"}}'
```

**Expected response:** 204.

### CHAT-14: Delete a message (Microsoft, soft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/chats/{cid}/messages/{mid}/softDelete"
```

**Expected response:** 204.

**Common errors:** Hard-delete (`DELETE`) only works for admins; prefer `softDelete`.

### CHAT-15: Start a new 1:1 chat (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/chats" --body '{
  "chatType":"oneOnOne",
  "members":[
    {"@odata.type":"#microsoft.graph.aadUserConversationMember","roles":["owner"],"user@odata.bind":"https://graph.microsoft.com/v1.0/users('<my-id>')"},
    {"@odata.type":"#microsoft.graph.aadUserConversationMember","roles":["owner"],"user@odata.bind":"https://graph.microsoft.com/v1.0/users('<their-id>')"}
  ]
}'
```

**Expected response:** 201. Idempotent — if a 1:1 already exists, Graph returns it.

**Common errors:** Both members must be `owner` role for 1:1. 403 → `apl login ms:<label> --force --scope Chat.Create`.

### CHAT-16: Send to a Teams channel (Microsoft)

**When to use:** "post in the channel", "post in volentis-eng".

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/teams/{teamId}/channels/{channelId}/messages" --body '{
  "body":{"content":"hi channel"}
}'
```

**Expected response:** 201.

**Common errors:** `ChannelMessage.Send` scope is separate from `ChatMessage.Send` — `apl login ms:<label> --force --scope ChannelMessage.Send`.

**User-visible formatting:** Confirm with message id; note channels live under Teams, chats do not.
