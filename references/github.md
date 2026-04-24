<!-- Generated from docs/specs/spec-recipes.md @ 11d9246 -->

# GitHub — recipes

Covers GitHub operations via the `gh` CLI (https://cli.github.com). All recipes
assume the user has run `gh auth login` once; the skill never handles GitHub
tokens directly.

Abbreviations used throughout:
- `<repo>` = `owner/name` (e.g. `muthuishere/all-purpose-login`). If omitted,
  `gh` uses the repo inferred from the current working directory's git remote.
- `<num>` = PR or issue number (integer).
- `<sha>` = short or full commit SHA.

**User-visible formatting (family default):**
- For list outputs, show: index, number, title, author, age, state/label.
- For single-item views, show a header block (number, title, state, author,
  branch) and then the body / comments / checks as collapsible sections.
- For write actions (approve, merge, comment, close), confirm with the
  resulting URL returned by `gh`.
- Never echo the token — `gh auth token` output is piped into consuming
  commands only when explicitly needed (rare; see Fallbacks).

---

## GitHub — repos

### GH-1: View a repo

**When to use:** "show me this repo", "what's the default branch", "describe the repo".

**Command:**
```bash
gh repo view <repo> --json name,nameWithOwner,description,defaultBranchRef,url,visibility,isArchived,isPrivate,stargazerCount,primaryLanguage
```

**Expected response (short):** `{ name, nameWithOwner, description, defaultBranchRef{name}, url, visibility, ... }` (exit 0).

**Common errors:**
- `HTTP 404: Not Found` → wrong owner/name or private repo w/o access → verify slug with `gh repo list`.
- `could not determine repository` → not in a git worktree and no `<repo>` arg → pass `<repo>` explicitly.

**User-visible formatting:** One-line summary: `<nameWithOwner>` · `<defaultBranchRef.name>` · `<visibility>` · `<description>`.

**Fallback:** `gh api repos/<repo>` if a raw field isn't surfaced in `--json`.

### GH-2: List my repos

**When to use:** "list my repos", "what repos do I own", "my github repos".

**Command:**
```bash
gh repo list --limit 50 --json nameWithOwner,description,visibility,updatedAt,isArchived
```

**Expected response (short):** JSON array of repo objects, newest-updated first.

**Common errors:**
- `HTTP 401` → `gh auth status`; if expired, `gh auth login`.

**User-visible formatting:** Numbered list: `nameWithOwner` — `description` (updated `<relative>`).

### GH-3: Clone a repo

**When to use:** "clone X", "grab a local copy".

**Command:**
```bash
gh repo clone <repo> [<dir>]
```

**Expected response:** Clone progress on stderr, exits 0.

**Common errors:**
- `fatal: destination path '...' already exists` → pick a different dir or remove the existing one.

**User-visible formatting:** "Cloned <repo> to <dir>."

### GH-4: Default branch of current repo

**When to use:** "what's the default branch", "where should I branch from".

**Command:**
```bash
gh repo view --json defaultBranchRef -q .defaultBranchRef.name
```

**Expected response:** A single branch name, e.g. `main`.

**Common errors:**
- `could not determine repository` → not in a git worktree → pass `--repo <repo>`.

**User-visible formatting:** "Default branch: `<name>`."

---

## GitHub — pull requests

### GH-5: PRs assigned to me

**When to use:** "my prs", "prs assigned to me", "what am I working on".

**Command:**
```bash
gh pr list --assignee @me --state open --json number,title,author,headRefName,baseRefName,url,updatedAt,isDraft
```

**Expected response:** Array of PR objects, newest first.

**Common errors:**
- Empty array → no PRs; render "No PRs assigned to you."

**User-visible formatting:** `#<num> <title> — <headRefName> → <baseRefName> (updated <relative>)`.

### GH-6: PRs requesting my review

**When to use:** "review queue", "prs waiting on me", "what do I need to review".

**Command:**
```bash
gh pr list --search "is:open review-requested:@me" --json number,title,author,headRefName,baseRefName,url,updatedAt
```

**Expected response:** Array of PRs where viewer is a requested reviewer.

**Common errors:**
- Confusingly shows PRs already reviewed → add `-review:@me` to the search.

**User-visible formatting:** Numbered list: `#<num> <title> by @<author.login> (<age>)`.

### GH-7: My open PRs (authored by me)

**When to use:** "my open prs", "prs I wrote".

**Command:**
```bash
gh pr list --author @me --state open --json number,title,url,headRefName,baseRefName,isDraft,reviewDecision
```

**Expected response:** PRs authored by viewer.

**Common errors:**
- Empty array → no open PRs authored by you.

**User-visible formatting:** `#<num> <title> — <reviewDecision|pending> (<headRefName>)`.

### GH-8: View a PR (comments + checks)

**When to use:** "show me PR 42", "what's the status of #42".

**Command:**
```bash
gh pr view <num> --comments
gh pr checks <num>
```

**Expected response:** Human-readable PR body + comment stream + check runs table.

**Common errors:**
- `no pull requests found` → wrong repo context → add `--repo <repo>`.

**User-visible formatting:** Header (title/state/author/branch), body, comments in order, then a "Checks:" table.

### GH-9: View PR diff

**When to use:** "show me the diff", "what changed in #42".

**Command:**
```bash
gh pr diff <num>
```

**Expected response:** Unified diff on stdout.

**Common errors:**
- Very large diffs → suggest `gh pr diff <num> --name-only` for a file list first.

**User-visible formatting:** Wrap in a code fence with `diff` language.

### GH-10: Checkout a PR locally

**When to use:** "pull down PR 42", "check out that branch".

**Command:**
```bash
gh pr checkout <num>
```

**Expected response:** Creates/fetches the PR's branch, switches to it.

**Common errors:**
- Dirty worktree → stash or commit first.

**User-visible formatting:** "Checked out `<branch>` from PR #<num>."

### GH-11: Approve a PR

**When to use:** "approve #42", "lgtm the PR".

**Command:**
```bash
gh pr review <num> --approve --body "LGTM"
```

**Expected response:** Review URL returned.

**Common errors:**
- `can not approve your own pull request` → GitHub policy; must be a different user.

**User-visible formatting:** "Approved PR #<num>: <url>."

### GH-12: Request changes on a PR

**When to use:** "block this PR", "request changes on #42".

**Command:**
```bash
gh pr review <num> --request-changes --body "<reason>"
```

**Expected response:** Review URL.

**Common errors:**
- `--body` is required when using `--request-changes`.

**User-visible formatting:** "Requested changes on #<num>."

### GH-13: Comment on a PR

**When to use:** "leave a comment on #42".

**Command:**
```bash
gh pr comment <num> --body "<text>"
```

**Expected response:** Comment URL.

**Common errors:**
- Locked conversation → `Error: Conversation is locked` — repo maintainer must unlock.

**User-visible formatting:** "Commented: <url>."

### GH-14: Merge a PR

**When to use:** "merge #42", "ship it".

**Command:**
```bash
gh pr merge <num> --squash --delete-branch
```

Alternatives: `--merge` (commit), `--rebase`. Omit `--delete-branch` to keep the branch.

**Expected response:** "Merged pull request #<num>".

**Common errors:**
- `Pull Request is not mergeable` → resolve conflicts locally, push, retry.
- `Required status check is expected` → wait for CI.
- `At least one approving review is required` → get an approval first.

**User-visible formatting:** Confirm destructive-ish action first. Then "Merged #<num> via squash."

### GH-15: Close a PR without merging

**When to use:** "close #42 without merging", "reject that PR".

**Command:**
```bash
gh pr close <num> --comment "<reason>"
```

**Expected response:** "Closed pull request #<num>".

**Common errors:**
- Already merged → `gh` returns a no-op message; cannot reopen a merged PR.

**User-visible formatting:** Confirm the close (destructive) before running.

---

## GitHub — issues

### GH-16: Issues assigned to me

**When to use:** "my issues", "issues assigned to me".

**Command:**
```bash
gh issue list --assignee @me --state open --json number,title,url,labels,updatedAt,repository
```

**Expected response:** Array of open issues assigned to viewer.

**Common errors:**
- Empty array → no issues assigned.

**User-visible formatting:** `#<num> <title> [<labels>] (<age>)`.

### GH-17: Issues mentioning me

**When to use:** "where am I mentioned", "open mentions".

**Command:**
```bash
gh search issues --mentions @me --state open --json number,title,url,repository,updatedAt
```

**Expected response:** Issues mentioning viewer across all accessible repos.

**Common errors:**
- Rate limited → GitHub search has a lower rate; retry after a minute.

**User-visible formatting:** `<repo.nameWithOwner>#<num> <title>`.

### GH-18: My open issues (authored by me)

**When to use:** "issues I opened", "my issues".

**Command:**
```bash
gh issue list --author @me --state open --json number,title,url,labels
```

**Expected response:** Array of open issues authored by viewer.

**Common errors:**
- Empty array → no open authored issues.

**User-visible formatting:** `#<num> <title>`.

### GH-19: View an issue

**When to use:** "show me issue 42", "open that issue".

**Command:**
```bash
gh issue view <num> --comments
```

**Expected response:** Header, body, comments.

**Common errors:**
- `HTTP 404` → wrong repo context → add `--repo <repo>`.

**User-visible formatting:** Header block + body + comments in order.

### GH-20: Create an issue

**When to use:** "open an issue", "file a bug".

**Command:**
```bash
gh issue create --title "<title>" --body "<body>" [--label bug] [--assignee @me]
```

**Expected response:** Issue URL printed on stdout.

**Common errors:**
- `label does not exist` → create the label first or drop `--label`.

**User-visible formatting:** "Created issue: <url>."

### GH-21: Close an issue

**When to use:** "close #42", "mark issue done".

**Command:**
```bash
gh issue close <num> --comment "<reason>"
```

**Expected response:** "Closed issue #<num>".

**Common errors:**
- Already closed → no-op, `gh` exits 0.

**User-visible formatting:** Confirm, then "Closed #<num>."

### GH-22: Reopen an issue

**When to use:** "reopen #42".

**Command:**
```bash
gh issue reopen <num>
```

**Expected response:** "Reopened issue #<num>".

**Common errors:**
- Already open → no-op.

**User-visible formatting:** "Reopened #<num>."

### GH-23: Label / unlabel an issue

**When to use:** "label #42 as bug", "remove wontfix from #42".

**Command:**
```bash
gh issue edit <num> --add-label "bug,backend"
gh issue edit <num> --remove-label "wontfix"
```

**Expected response:** "Updated issue #<num>".

**Common errors:**
- `could not add label: not found` → label must pre-exist; create via `gh label create`.

**User-visible formatting:** "Updated #<num> labels."

### GH-24: Comment on an issue

**When to use:** "comment on #42".

**Command:**
```bash
gh issue comment <num> --body "<text>"
```

**Expected response:** Comment URL.

**Common errors:**
- Locked conversation → repo maintainer must unlock.

**User-visible formatting:** "Commented: <url>."

---

## GitHub — reviews

### GH-25: My pending reviews

**When to use:** "reviews I haven't finished", "draft reviews".

**Command:**
```bash
gh pr list --search "is:open review-requested:@me draft:false" --json number,title,url
```

**Expected response:** PRs awaiting this reviewer's action.

**Common errors:**
- Includes PRs already approved by you → add `-reviewed-by:@me` to the search string.

**User-visible formatting:** Numbered list; flag any older than 3 days.

**Fallback:** `gh api graphql -f query='...'` with `viewer { pullRequests(states: OPEN) { ... } }` for pending-submitted review drafts (rare).

### GH-26: Approve with body + file-level comments

**When to use:** "approve with inline comments".

**Command:**
```bash
gh pr review <num> --approve --body "Looks good"
```

For inline comments, use the web UI or `gh api` POST to `repos/<repo>/pulls/<num>/reviews` with a `comments` array.

**Expected response:** Review URL.

**Common errors:**
- Cannot approve your own PR — GitHub policy.

**User-visible formatting:** "Approved." with link.

---

## GitHub — CI / Actions

### GH-27: List recent workflow runs

**When to use:** "latest ci runs", "what's building", "actions status".

**Command:**
```bash
gh run list --limit 10 --json databaseId,name,status,conclusion,headBranch,event,updatedAt,url
```

**Expected response:** Array of run objects, newest first.

**Common errors:**
- `no runs found` → Actions not enabled on the repo, or no workflows have fired yet.

**User-visible formatting:** Table: id · workflow name · branch · status/conclusion · age.

### GH-28: View run status + failing step logs

**When to use:** "why did CI fail", "show me the failing logs".

**Command:**
```bash
gh run view <run-id> --log-failed
```

**Expected response:** Step-by-step status followed by logs for failed steps only.

**Common errors:**
- `run is still in_progress` → wait, or pass `--exit-status` in a polling loop.
- Very long logs → suggest `| tail -n 200` downstream.

**User-visible formatting:** Print the failing step name, then the last ~50 lines of its log.

### GH-29: Re-run a workflow

**When to use:** "rerun that CI job", "retry failed jobs".

**Command:**
```bash
gh run rerun <run-id> [--failed]
```

`--failed` re-runs only failed jobs (saves CI minutes).

**Expected response:** "Requested rerun of run <id>".

**Common errors:**
- Run still in progress → cannot rerun; wait for completion.

**User-visible formatting:** "Re-running run <id>."

### GH-30: Cancel a workflow run

**When to use:** "stop that CI run", "cancel run 12345".

**Command:**
```bash
gh run cancel <run-id>
```

**Expected response:** "Requested cancellation of run <id>".

**Common errors:**
- Run already completed → no-op.

**User-visible formatting:** "Cancelled run <id>."

### GH-31: Watch a run until it finishes

**When to use:** "wait for CI", "tell me when the build is done".

**Command:**
```bash
gh run watch <run-id> --exit-status
```

**Expected response:** Streams live status; exits 0 on success, 1 on failure.

**Common errors:**
- Long-running jobs → may exceed the agent's tool timeout; consider polling with `gh run view <id> --json status` instead.

**User-visible formatting:** "Run <id> finished: <conclusion>."

---

## GitHub — releases

### GH-32: List releases

**When to use:** "list releases", "version history".

**Command:**
```bash
gh release list --limit 20
```

**Expected response:** Table of tag, title, type (Latest/Pre-release), published-at.

**Common errors:**
- Empty output → repo has no releases yet.

**User-visible formatting:** Pass-through the table.

### GH-33: Latest release

**When to use:** "what's the latest release", "current version".

**Command:**
```bash
gh release view --json tagName,name,publishedAt,url,body
```

**Expected response:** `{ tagName, name, publishedAt, url, body }`.

**Common errors:**
- `release not found` → no releases on the repo.

**User-visible formatting:** "Latest: `<tagName>` (<publishedAt>). <url>".

### GH-34: Create a release with notes + artifacts

**When to use:** "cut v1.2.0", "publish a release".

**Command:**
```bash
gh release create <tag> ./dist/*.tar.gz \
  --title "v1.2.0" \
  --notes "$(cat CHANGELOG.md)" \
  [--draft] [--prerelease] [--generate-notes]
```

**Expected response:** Release URL printed on stdout.

**Common errors:**
- `tag already exists` → bump tag or add `--target <branch>`.
- Artifact glob matched no files → check path.

**User-visible formatting:** "Released <tag>: <url>. Uploaded N artifacts."

---

## GitHub — search

### GH-35: Search code

**When to use:** "find X in repo Y", "who calls function Z".

**Command:**
```bash
gh search code "<query>" --limit 30 --json repository,path,textMatches
```

**Expected response:** Matching code hits, with path + surrounding lines.

**Common errors:**
- `validation failed` → code search needs a qualifier (`repo:`, `org:`, `language:`) for non-admin users.

**User-visible formatting:** `<repo.nameWithOwner>:<path>` plus a snippet per match.

### GH-36: Search issues

**When to use:** "find issues about X", "search issues for rate limit".

**Command:**
```bash
gh search issues "<query>" --state open --limit 30 --json number,title,repository,url
```

**Expected response:** Array of matching issues across accessible repos.

**Common errors:**
- No qualifier → very broad; add `repo:` or `org:` to narrow.

**User-visible formatting:** `<repo>#<num> <title>`.

### GH-37: Search PRs

**When to use:** "find PRs about X", "search merged PRs".

**Command:**
```bash
gh search prs "<query>" --state open --limit 30 --json number,title,repository,url,author
```

**Expected response:** Array of matching PRs.

**Common errors:**
- No qualifier → broad; add `repo:` / `author:` / `is:merged` to narrow.

**User-visible formatting:** `<repo>#<num> <title> — @<author.login>`.

---

## Fallback — raw `gh api`

For anything the `gh` high-level commands don't cover (rare: custom GraphQL,
undocumented endpoints, enterprise admin APIs), drop to:

```bash
gh api repos/<repo>/<endpoint>                       # REST
gh api graphql -f query='query { viewer { login } }' # GraphQL
```

If you truly need a raw bearer (pre-signed URL download, third-party tool
integration), pipe it in — never echo it:

```bash
curl -H "Authorization: Bearer $(gh auth token)" ...
```

Only use this pattern when `gh api` cannot express the call. The vast majority
of GitHub intents are covered by the recipes above.
