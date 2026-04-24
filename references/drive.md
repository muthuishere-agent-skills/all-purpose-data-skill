<!--
  Generated from docs/specs/spec-recipes.md @ d928041
  Keep in sync manually. On recipe churn, regenerate this section.
-->

# Drive / OneDrive / SharePoint — recipes

Covers Microsoft OneDrive + SharePoint (`ms:<label>`) and Google Drive
(`google:<label>`). The two halves differ substantially — pick the recipe
family matching `{active_provider}`.

Abbreviations:
- `$GRAPH` = `https://graph.microsoft.com/v1.0`
- `$DRIVE` = `https://www.googleapis.com/drive/v3`

**User-visible formatting (family default):**
- File lists: name + size (human-readable) + mimeType + modified date.
- Download actions: confirm destination path + bytes written.
- Export actions: confirm format + destination.
- Share actions: show the created webUrl / permission id.

---

## OneDrive / SharePoint (Microsoft)

### DRIVE-1: Recent files (OneDrive)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/drive/recent"
```

**Common errors:** 403 → `apl login ms:<label> --force --scope Files.Read`.

### DRIVE-2: Shared with me (OneDrive)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/drive/sharedWithMe"
```

**Common errors:** 403 → `apl login ms:<label> --force --scope Files.Read.All`.

### DRIVE-3: Search drive (OneDrive)

**When to use:** "search my onedrive for kickoff".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/drive/root/search(q='kickoff')"
```

### DRIVE-4: List folder children (OneDrive)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/drive/root:/Documents:/children"
```

**Common errors:** URL-encode each segment with spaces individually: `/Meet%20Recordings:/children`.

### DRIVE-5: Download non-native file (OneDrive)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/drive/items/{itemId}/content" -o file.bin
```

**Expected response:** 200 after following redirects (`apl call` follows by default).

**Common errors:** The 302 target is a pre-authenticated storage URL. For large files or when download stalls, prefer reading `@microsoft.graph.downloadUrl` from the item metadata and curl-ing that URL WITHOUT the Bearer token (see MEET-9 Step 3 pattern).

### DRIVE-6: Single item metadata (OneDrive / SharePoint drive)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/drives/{driveId}/items/{itemId}"
```

**Expected response:** `{ id, name, size, webUrl, @microsoft.graph.downloadUrl? }`.

### DRIVE-7: Create folder (OneDrive)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/drive/root/children" --body '{
  "name":"New",
  "folder":{},
  "@microsoft.graph.conflictBehavior":"rename"
}'
```

**Expected response:** 201.

### DRIVE-8: Upload small file (OneDrive, <4MB) — FALLBACK

**Fallback:** `apl call` does not stream raw bytes as a body — use curl:
```bash
TOKEN=$(apl login ms:<label>)
curl -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: text/plain" \
  --data-binary @./hello.txt \
  -X PUT "$GRAPH/me/drive/root:/hello.txt:/content"
```

**Expected response:** 201 or 200; driveItem.

**Common errors:** Files >4MB → use upload session (`POST .../createUploadSession`), out of v1 scope.

### DRIVE-9: Share a file (OneDrive)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/drive/items/{id}/createLink" --body '{
  "type":"view",
  "scope":"organization"
}'
```

**Expected response:** `{ link: { webUrl, ... } }`.

### DRIVE-10: List permissions (OneDrive)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/drive/items/{id}/permissions"
```

### DRIVE-11: OneDrive delta

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/drive/root/delta"
# Later: GET <saved @odata.deltaLink>
```

### DRIVE-12: SharePoint site root (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/sites/root"
# Or by hostname: $GRAPH/sites/{tenant}.sharepoint.com:/sites/{site}
```

**Common errors:** 403 → `apl login ms:<label> --force --scope Sites.Read.All` (admin consent required on most tenants).

---

## Google Drive

### DRIVE-13: Recent files (Google Drive)

**When to use:** "recent files in my drive".

**Command:**
```bash
apl call google:<label> GET "$DRIVE/files?pageSize=20&orderBy=modifiedTime%20desc&fields=files(id,name,mimeType,size,modifiedTime,webViewLink,owners)"
```

**Expected response:** `{ files: [...], nextPageToken? }`.

**Common errors:** Without `fields=`, only `id,name,mimeType` are returned. 403 → `apl login google:<label> --force --scope drive.readonly`.

### DRIVE-14: Search by name (Google Drive)

**Command:**
```bash
Q=$(python3 -c "import urllib.parse;print(urllib.parse.quote(\"name contains 'budget'\"))")
apl call google:<label> GET "$DRIVE/files?q=$Q&pageSize=20&fields=files(id,name,mimeType,size,webViewLink)"
```

### DRIVE-15: Search by MIME type (Google Drive)

**Command:**
```bash
Q=$(python3 -c "import urllib.parse;print(urllib.parse.quote(\"mimeType='video/mp4'\"))")
apl call google:<label> GET "$DRIVE/files?q=$Q&pageSize=20&fields=files(id,name,size)"
```

**Google Drive `q=` cheatsheet:** `name = 'x'`, `name contains 'x'`, `fullText contains 'x'`, `mimeType = '...'`, `'<folderId>' in parents`, `sharedWithMe`, `starred = true`, `trashed = false`, `modifiedTime > '2026-04-01T00:00:00'`, `owners in 'me'`. Combine with `and`/`or`. Use single quotes in `q=` for string values.

### DRIVE-16: Shared with me (Google Drive)

**Command:**
```bash
apl call google:<label> GET "$DRIVE/files?q=sharedWithMe&pageSize=50&fields=files(id,name,mimeType,owners,sharingUser)"
```

### DRIVE-17: List folders only (Google Drive)

**Command:**
```bash
Q=$(python3 -c "import urllib.parse;print(urllib.parse.quote(\"mimeType='application/vnd.google-apps.folder'\"))")
apl call google:<label> GET "$DRIVE/files?q=$Q"
```

### DRIVE-18: Children of a folder (Google Drive)

**Command:**
```bash
Q=$(python3 -c "import urllib.parse;print(urllib.parse.quote(\"'<folderId>' in parents and trashed=false\"))")
apl call google:<label> GET "$DRIVE/files?q=$Q"
```

### DRIVE-19: Download non-native file (Google Drive)

**When to use:** "download that pdf from drive".

**Command:**
```bash
apl call google:<label> GET "$DRIVE/files/{id}?alt=media" -o file.bin
```

**Expected response:** 200 via signed-storage 302 redirects.

**Common errors:** `alt=media` returns **403** for native Google files (Docs, Sheets, Slides, Forms). Use DRIVE-20/21/22 (export) instead.

### DRIVE-20: Export Google Doc to PDF

**When to use:** "export this google doc as pdf".

**Command:**
```bash
apl call google:<label> GET "$DRIVE/files/{id}/export?mimeType=application/pdf" -o doc.pdf
```

**Expected response:** 200 application/pdf.

### DRIVE-21: Export Google Sheet to xlsx

**Command:**
```bash
apl call google:<label> GET "$DRIVE/files/{id}/export?mimeType=application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" -o sheet.xlsx
```

### DRIVE-22: Export Google Slides to pptx

**Command:**
```bash
apl call google:<label> GET "$DRIVE/files/{id}/export?mimeType=application/vnd.openxmlformats-officedocument.presentationml.presentation" -o slides.pptx
```

### DRIVE-23: Single file metadata (Google Drive)

**Command:**
```bash
apl call google:<label> GET "$DRIVE/files/{id}?fields=id,name,mimeType,size,webViewLink,owners,permissions"
```

### DRIVE-24: List permissions (Google Drive)

**Command:**
```bash
apl call google:<label> GET "$DRIVE/files/{id}/permissions"
```

**Expected response:** `{ permissions: [{id, type, role, emailAddress?, domain?}, ...] }`.

### DRIVE-25: Share a file (Google Drive)

**Command:**
```bash
apl call google:<label> POST "$DRIVE/files/{id}/permissions" --body '{
  "role":"reader",
  "type":"user",
  "emailAddress":"x@y.com"
}'
```

**Expected response:** 200; created permission.

**Common errors:** `drive.readonly` does NOT allow permission writes → `apl login google:<label> --force --scope drive`.

### DRIVE-26: Create folder (Google Drive)

**Command:**
```bash
apl call google:<label> POST "$DRIVE/files" --body '{
  "name":"apl-inbox",
  "mimeType":"application/vnd.google-apps.folder"
}'
```

**Expected response:** 200; folder file object.

### DRIVE-27: Drive changes feed (Google Drive delta)

**Bootstrap:**
```bash
apl call google:<label> GET "$DRIVE/changes/startPageToken"
```

**Subsequent:**
```bash
apl call google:<label> GET "$DRIVE/changes?pageToken=<token>"
```

**Expected response:** `{ changes: [...], newStartPageToken?, nextPageToken? }`.
