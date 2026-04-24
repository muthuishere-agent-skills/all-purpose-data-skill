---
name: all-purpose-data-skill
---

# Handle selection

How the skill picks `ms:<label>` vs `google:<label>` for a given intent.

## Inventory — `apl accounts --json`

```bash
apl accounts --json
```

Returns a JSON array. Each element is an object with at least:

```json
{
  "handle": "google:work",
  "provider": "google",
  "label": "work",
  "tenant": "-",
  "scopes": ["gmail.readonly", "gmail.send", "calendar", "..."]
}
```

Empty array (`[]`) → no accounts configured. Route the user to setup:
- wants Google → `setup-google.md`
- wants Microsoft → `setup-microsoft.md`

## Presenting the picker

Group by provider, list each handle. Example:

```
Google:
  google:work
  google:personal

Microsoft:
  ms:volentis

Which should I use for this session?
```

The user responds with a handle string (or a shortcut like "personal" → resolve
by suffix match; if ambiguous, ask again).

Cache:

```
active_handle: google:work
active_provider: google
```

for the remainder of the session.

## Compatibility rules per intent

Use this table to decide whether `{active_provider}` can serve the current
intent, or whether to scan for / switch to a compatible handle.

| Intent family | ms:* can serve? | google:* can serve? | Notes |
|---|---|---|---|
| Mail read | yes | yes | Graph Mail vs Gmail — mirror |
| Mail send | yes | yes | mirror |
| Calendar read | yes | yes | mirror |
| Calendar write | yes | yes | mirror |
| Teams chat / channel | yes | **no** | Microsoft-only |
| Online meetings / recordings / transcripts | yes | **no** | Microsoft-only |
| OneDrive / SharePoint | yes | **no** | Microsoft-only |
| Google Drive (search, metadata, download) | **no** | yes | Google-only |
| Google Docs / Sheets / Slides export | **no** | yes | Google-only |
| Google People (contacts) | **no** | yes | Google-only |
| Microsoft contacts (`/me/contacts`) | yes | **no** | Microsoft-only |
| Directory search (`$GRAPH/users`) | yes | **no** | Microsoft-only |
| Google Workspace directory (`people:listDirectoryPeople`) | **no** | yes | Google-only |
| Presence | yes | **no** | Microsoft-only |

## Auto-switch pseudocode

```
if intent.is_compatible_with(active_provider):
    use active_handle
else:
    compatible = [a for a in accounts() if intent.is_compatible_with(a.provider)]
    if len(compatible) == 1:
        tell user: "Switched to <handle> for this (<intent-family> is <provider>-only)."
        active_handle = compatible[0].handle
    elif len(compatible) == 0:
        tell user: "This needs a <required-provider> account. Run: apl setup <provider>"
        route to setup-<provider>.md
        stop
    else:
        ask user to pick among compatible handles
```

## Remembering the choice

Once the user has picked, do not re-ask for the remainder of the session
unless:

- They explicitly say "switch" / "use X instead" / "change account".
- A compatibility mismatch forces a temporary switch (announced).
- The session ends (new Claude Code session = fresh state).

## GitHub repo selection

GitHub recipes (see `github.md`) operate on a `<repo>` = `owner/name`. The
skill resolves `gh_default_repo` by the same layered lookup as a handle:
session > project > global > ask.

**Resolution order on first GitHub intent of a session:**

1. Session override? (user said "for muthuishere/foo…") → use it, do not persist.
2. `project.state.yaml` → `gh_default_repo`? → use it.
3. Cwd is a git repo with a GitHub remote?
   ```bash
   gh repo view --json nameWithOwner -q .nameWithOwner
   ```
   If this exits 0, offer: *"Use `<nameWithOwner>` as the default repo for this project? (Y/switch)"*. On confirm, write to project state.
4. Else prompt: *"Which repo? (owner/name)"*. Validate via `gh repo view <x> --json nameWithOwner` before caching.
5. Write to `project.state.yaml` → `gh_default_repo` on confirm.

**Switch triggers:** user says "switch repo", "use X repo instead", "for
`<other-repo>`" → re-run the picker, overwrite state.

**Multi-repo intents** (e.g. "my PRs across all repos" — GH-5 without
`--repo`) do NOT need `gh_default_repo` — `gh` already scopes by `@me`. Only
ask when a recipe needs a concrete `<repo>`.

**Pseudocode:**

```
def resolve_repo(intent):
    if session.repo_override:
        return session.repo_override
    if project_state.gh_default_repo:
        return project_state.gh_default_repo
    try:
        r = run("gh repo view --json nameWithOwner -q .nameWithOwner")
        if confirm_with_user(f"Use {r} as default?"):
            project_state.gh_default_repo = r
            return r
    except NotAGitRepo, NoGhRemote:
        pass
    r = ask_user("Which repo? (owner/name)")
    validate(r)
    project_state.gh_default_repo = r
    return r
```

## Missing-scope handling

`apl accounts --json` returns the scopes granted per handle. If a recipe's
required scope is not present, suggest:

```bash
apl login <handle> --force --scope <missing-scope>
```

Do this **before** issuing the call when the mismatch is obvious from
`apl accounts --json`. Otherwise, react to the 403 at call time per
`workflow.md` failure handling.
