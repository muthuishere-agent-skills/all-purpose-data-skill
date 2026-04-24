---
name: all-purpose-data-skill
---

# Setup — Google

The skill never asks for a client id or secret. All registration happens
inside the `apl setup google` bootstrapper.

## Entry point

```bash
apl setup google
```

This uses `gcloud` to create (or reuse) a GCP project named `apl-*`, enables
the Gmail / Calendar / People APIs, and then walks the user through a short
OAuth-consent-screen setup in the Google Cloud Console (the single manual
segment).

## What the user will see

1. **Preflight.**
   - `command -v gcloud` — gcloud CLI on PATH.
   - `gcloud auth list --filter=status:ACTIVE` — an active account.

   If either fails:
   ```
   ✗ Google setup needs the gcloud CLI.
       Install: https://cloud.google.com/sdk/docs/install
   ```
   or
   ```
   ✗ gcloud is installed but not logged in.
       Run: gcloud auth login
   ```

2. **Pick an existing `apl-*` project or create a new one.**

   ```
   Existing apl-* GCP projects:
     1) apl-muthu-macbook    (All Purpose Login — muthu's mbp)
     2) Create a new project
   Choose [1]:
   ```

3. **APIs enabled.** `apl` runs:
   ```bash
   gcloud services enable \
     gmail.googleapis.com \
     calendar-json.googleapis.com \
     people.googleapis.com \
     --project <id>
   ```

4. **Guided console walkthrough — Step 1 of 3: OAuth consent screen.**

   `apl` opens the URL:
   ```
   https://console.cloud.google.com/apis/credentials/consent?project=<id>
   ```

   The modern Google console calls this path the **OAuth Platform wizard**:
   - Left nav: **APIs & Services → Data Access → Audience → Clients**.
   - Set:
     - User Type: **External**
     - App name: `apl (local)`
     - User support email: the user's email
     - Developer contact: the user's email
     - Scopes: **leave empty** — `apl` requests scopes at login time via the
       "Manually add scopes" paste box only if prompted. Do NOT
       pre-add scopes here.
     - Test users: add the user's own email.

   Click SAVE AND CONTINUE through each page. Keep in "Testing" is fine; no
   verification review is required for personal use.

5. **Step 2 of 3: Create the OAuth 2.0 Client ID.**

   URL:
   ```
   https://console.cloud.google.com/apis/credentials?project=<id>
   ```

   Click **+ CREATE CREDENTIALS → OAuth client ID**.
   - Application type: **Desktop app**
   - Name: `apl-desktop`

   Click CREATE. A dialog shows Client ID and Client secret.

6. **Step 3 of 3: Paste the Client ID.**

   `apl` prompts:
   ```
   Client ID: _
   ```

   Paste only the **Client ID** (ends with `.apps.googleusercontent.com`). If
   the user pastes a full downloaded JSON, `apl` extracts `client_id` and
   ignores the rest — the secret is never stored.

   `apl` then validates the ID by running a real PKCE loopback exchange
   (requesting `openid email profile`) and checks the returned ID token's
   email matches the `gcloud` active account.

7. **Config written** to `~/.config/apl/config.yaml` under `google:`.

8. **First login.**

   ```bash
   apl login google:<label>
   ```

   Default scope set requested at first login (if `--scope` not specified):
   Gmail read / send / modify, Calendar, People, plus OIDC baseline.

## Adding a second Google account

```bash
apl login google:personal --force
```

`--force` opens the browser even when a record exists; the new label gets its
own stored record.

## Troubleshooting

### `gcloud` not installed
Install per https://cloud.google.com/sdk/docs/install. Do not attempt to
script the install.

### `gcloud auth login` needed
```bash
gcloud auth login
```
Then re-run `apl setup google`.

### Project create fails
`apl` prints the raw `gcloud` stderr. Common causes:
- Project-create quota exceeded (new accounts are limited) — delete an
  unused project or request a quota bump.
- Org policy blocks the `apl-*` naming scheme — use a different prefix by
  running `apl setup google --reconfigure` and entering a custom id.
- ID already taken (global namespace) — re-run to generate a fresh suffix.

### Client ID can't be found / OAuth round-trip fails

```
✗ That Client ID didn't complete the OAuth handshake.
  Google returned: invalid_client
  Common causes:
    — You copied the client SECRET instead of the ID
    — The consent screen in Step 1 hasn't been saved yet
    — Your email isn't in the Test Users list
  Try again? [Y/n]:
```

Most common: the client id was copied without hitting SAVE on the consent
screen, or the user's email isn't listed as a Test User.

### Can't find the client JSON
The JSON download is optional. You only need the **Client ID** string. If
neither the dialog nor the downloaded JSON are accessible, return to
`https://console.cloud.google.com/apis/credentials?project=<id>` and click
the OAuth client row — the ID is visible there.

### Scopes missing later
When a recipe 403s with "insufficient scope":
```bash
apl login google:<label> --force --scope <scope>
```
The scope name is listed on each recipe's `**Scopes:**` line (e.g.
`gmail.send`, `calendar`, `drive.readonly`).

## What this file does NOT cover

- GCP billing — not required for OAuth usage of the productivity APIs listed.
- Domain-wide delegation — out of scope.
- Service accounts — out of scope (delegated user auth only).
- Manually pasting tokens — the skill never accepts raw tokens.
