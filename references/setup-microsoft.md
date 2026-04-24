---
name: all-purpose-data-skill
---

# Setup — Microsoft

The skill never asks for a client id, tenant id, or secret. All registration
happens inside the `apl setup ms` bootstrapper.

## Entry point

```bash
apl setup ms
```

Alias: `apl setup microsoft`. Or `apl setup` to run both providers together.

This uses the Azure CLI to create (or reuse) an app registration under the
user's signed-in tenant. No manual Azure Portal clicking.

## What the user will see

1. **Preflight.**
   - `command -v az` — Azure CLI on PATH.
   - `az account show` — logged in to some tenant.

   If either fails, `apl setup ms` prints the exact remediation:

   ```
   ✗ Microsoft setup needs the Azure CLI.
       Install: https://learn.microsoft.com/cli/azure/install-azure-cli
       Or:      brew install azure-cli
   ```
   or
   ```
   ✗ Azure CLI is installed but not logged in.
       Run: az login
   ```

2. **Pick an existing registration or create a new one.**

   `apl` lists any app whose name starts with `apl-` in the active tenant:

   ```
   Existing apl app registrations in this tenant:
     1) apl-muthu-macbook     (appId: 1111-...-5555)
     2) Create a new one
   Choose [1]:
   ```

   Default is reuse. Choose "Create a new one" to mint `apl-<whoami>-<hex>`.

3. **Scopes are granted automatically.**

   The default delegated scope set is added without admin consent:
   `User.Read`, `offline_access`, `openid`, `email`, `profile`,
   `Mail.ReadWrite`, `Mail.Send`, `Calendars.ReadWrite`, `Chat.ReadWrite`,
   `ChatMessage.Send`, `OnlineMeetings.Read`.

4. **Opt-in admin-consent scope prompt.**

   ```
   Include OnlineMeetingRecording.Read.All? (requires tenant admin consent) [y/N]:
   ```

   Answer `y` only if the user IS or has a path to a tenant admin. If yes,
   the skill surfaces the follow-up admin-consent command:

   ```
   note: OnlineMeetingRecording.Read.All requires tenant admin consent. As tenant admin, run:
       az ad app permission admin-consent --id <appId>
   ```

5. **Config is written** to `~/.config/apl/config.yaml` under the `microsoft:`
   block (client id + tenant + display name).

6. **First login.**

   ```bash
   apl login ms:<label>
   ```

   Pick any label — e.g. `volentis`, `reqsume`, `work`. The browser opens;
   user consents; `apl` stores the record. Subsequent `apl call …` will
   inject the token automatically.

## Adding a second Microsoft account

Just run `apl login` with a new label:

```bash
apl login ms:personal --force
```

`--force` always opens the browser even when a cached record exists. Use a
different label for each account so they coexist in `apl accounts`.

## Troubleshooting

### `az` not installed
The skill surfaces the exact install command. Do NOT attempt to script
installation on the user's behalf — let them own it.

```
brew install azure-cli
```

### `az account show` fails / not logged in
```bash
az login
```
Then re-run `apl setup ms`.

### Creating the app registration fails
`apl setup ms` prints the raw `az` stderr. Common causes:
- User lacks permission to create app registrations in their tenant — ask a
  tenant admin to create one, or use a personal Microsoft account.
- Sign-in audience policy blocks `AzureADandPersonalMicrosoftAccount` — ask
  the admin to relax or change audience.

### Admin consent not granted
Delegated scopes in the default set consent at login time. Only
`OnlineMeetingRecording.Read.All` (opt-in) needs admin consent:

```bash
az ad app permission admin-consent --id <appId>
```

Without admin consent, meeting recording / transcript recipes
(`MEET-5`, `MEET-6`, `MEET-7`) return 403. `MEET-9` (chat-iteration path)
works without this scope.

### Wrong tenant
```bash
az account set --subscription <sub-id-in-target-tenant>
```
Then re-run `apl setup ms --reconfigure`.

## What this file does NOT cover

- Device code flow — out of scope.
- App-only (client credentials) flows — out of scope.
- Manually registering an app through the Azure Portal — unnecessary, use
  `apl setup ms`.
- Paste-a-token workflows — the skill never accepts raw tokens.
