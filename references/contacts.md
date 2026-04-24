<!--
  Generated from docs/specs/spec-recipes.md @ d928041
  Keep in sync manually. On recipe churn, regenerate this section.
-->

# Contacts / People — recipes

Covers Microsoft Graph Contacts + Directory (`ms:<label>`) and Google People
API (`google:<label>`).

Also includes the Identity-family recipes that fit the "who is X / find X"
intent (IDENT-5/6/7 from the spec), because users don't distinguish
"contacts" from "directory lookup".

Abbreviations:
- `$GRAPH` = `https://graph.microsoft.com/v1.0`
- `$PEOPLE` = `https://people.googleapis.com/v1`

**User-visible formatting (family default):**
- Contacts / people: display name, primary email, phone, (org for Microsoft
  directory entries).
- Create actions: confirm with the new contact's resource name / id.

---

## Microsoft

### CONT-1: My contacts (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/contacts?\$top=50"
```

**Expected response:** `{ value: [{id, displayName, emailAddresses, ...}, ...] }`.

**Common errors:** 403 → `apl login ms:<label> --force --scope Contacts.Read`.

### CONT-2: Contact folders (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/contactFolders"
```

### CONT-3: Create contact (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/contacts" --body '{
  "givenName":"Shaama",
  "surname":"Manoharan",
  "emailAddresses":[{"address":"shaama@reqsume.com","name":"Shaama"}]
}'
```

**Expected response:** 201.

**Common errors:** 403 → `apl login ms:<label> --force --scope Contacts.ReadWrite`.

### IDENT-6: Directory search (Microsoft)

**When to use:** "find X in the directory", "who is X at work".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/users?\$search=\"displayName:shaama\"" -H 'ConsistencyLevel: eventual'
```

**Expected response:** `{ value: [{id, displayName, mail, jobTitle}, ...] }`.

**Common errors:** `$search` **requires** `ConsistencyLevel: eventual`; omitting 400s. Quote values with `"..."`.

### IDENT-7: Look up user by email (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/users/shaama@reqsume.com?\$select=id,displayName,mail,jobTitle"
```

**Common errors:** 404 for external / personal addresses not in the tenant directory.

---

## Google

### CONT-4: My connections (Google)

**Command:**
```bash
apl call google:<label> GET "$PEOPLE/people/me/connections?personFields=names,emailAddresses,phoneNumbers&pageSize=100"
```

**Expected response:** `{ connections: [...], nextPageToken?, totalPeople }`.

**Common errors:** `personFields` is required; 400 if missing. 403 → `apl login google:<label> --force --scope contacts.readonly`.

### CONT-5: Search contacts (Google)

**When to use:** "look up X in my contacts".

**Command:**
```bash
apl call google:<label> GET "$PEOPLE/people:searchContacts?query=shaama&readMask=names,emailAddresses"
```

**Expected response:** `{ results: [{person: {...}}, ...] }`.

### CONT-6: Other contacts (Google, auto-populated from Gmail)

**Command:**
```bash
apl call google:<label> GET "$PEOPLE/otherContacts?readMask=names,emailAddresses&pageSize=100"
```

**Common errors:** This endpoint uses `readMask`, NOT `personFields`. Separate scope: `apl login google:<label> --force --scope contacts.other.readonly`.

### CONT-7: Directory people (Google Workspace)

**When to use:** "find X in the domain directory".

**Command:**
```bash
apl call google:<label> GET "$PEOPLE/people:listDirectoryPeople?sources=DIRECTORY_SOURCE_TYPE_DOMAIN_PROFILE&readMask=names,emailAddresses&pageSize=50"
```

**Common errors:** Workspace-only; personal Google accounts 403. 403 → `apl login google:<label> --force --scope directory.readonly`.

### CONT-8: Create contact (Google)

**Command:**
```bash
apl call google:<label> POST "$PEOPLE/people:createContact" --body '{
  "names":[{"givenName":"Shaama"}],
  "emailAddresses":[{"value":"shaama@reqsume.com"}]
}'
```

**Expected response:** 200; created person resource.

**Common errors:** 403 → `apl login google:<label> --force --scope contacts`.
