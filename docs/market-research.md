# Market research — all-purpose-data-skill (April 2026)

Snapshot of the competitive landscape for the skill + `apl` pair, written to
inform roadmap and positioning decisions. Not a marketing doc — uses the
skill's own framing (handles, recipes, fan-out, token-frugal defaults).

---

## 1. What the skill is, in one paragraph

`all-purpose-data-skill` is a Claude Code / Codex agent skill that converts
natural-language productivity asks ("send an email", "what's on my calendar",
"find last week's Teams recording", "morning brief") into authenticated HTTP
calls across **Google Workspace**, **Microsoft 365**, and **GitHub**. It is
the *routing + recipe layer*. Token brokerage is fully delegated to
[`apl`](https://github.com/muthuishere/all-purpose-login), which owns the
OAuth dance, encrypted token storage in the OS keychain, and 401
refresh-retry. The headline flow is **Morning Brief**: one turn aggregates
today's meetings, unread mail, new Teams messages, and the user's GitHub
PR / issue queue, fanning out across every configured handle in parallel.

Notable design choices:

- **Cross-provider fan-out by default.** "What's in my inbox" hits Gmail
  *and* Outlook in parallel; results are merged and tagged by handle.
- **Token-frugal defaults.** Gmail filtered to
  `in:inbox category:primary is:unread newer_than:1d`, Graph filtered to
  unread non-junk, capped at 20–30 items. Explicit recipe-level rules
  fight LLM context bloat.
- **Walls reported honestly.** 403s from SharePoint ACLs, DLP, or
  admin-consent are surfaced with the documented workaround, not retried.
- **BYO cloud project.** User creates their own Azure AD app + GCP OAuth
  client — free for personal use, no SaaS middleman.
- **Local-first, no telemetry.** Tokens in OS keychain; only network
  traffic is to provider APIs.

---

## 2. Market scan

Five buckets, ranked by competitive proximity.

### A. First-party AI productivity assistants — the strongest competition

| Product | Coverage | Pricing | Posture |
|---|---|---|---|
| **Anthropic Claude Cowork** | Gmail, Calendar, Slack, Sentry, GitHub — first-party briefing | Bundled with Claude plans | Closed, opinionated, SaaS |
| **Microsoft Work IQ MCP** (preview) | Outlook Mail/Calendar, Teams, Files via Graph | Requires M365 Copilot ~$30/user/mo | Tenant-managed, enterprise |
| **Google Labs CC** | Gmail + Calendar morning brief by email | Free, Gmail-only | Closed, Google-only |
| **Anthropic Microsoft 365 connector** | Outlook, OneDrive, SharePoint, Teams | Recently expanded to all paid Claude plans | Closed connector |

**Implication.** Cowork directly overlaps the Morning Brief use case for
Anthropic users. The skill's wedge is multi-handle fan-out, GitHub-native
ergonomics, no SaaS lock-in, and parity in both Claude Code and Codex.

### B. Single-provider MCP servers — the long tail

| Server | Reach | Notes |
|---|---|---|
| `softeria/ms-365-mcp-server` | Largest MS-side, 200+ tools | 1-to-1 Graph endpoint mapping; no Google, no GitHub, no aggregation |
| `elyxlz/microsoft-mcp` | "Minimal, powerful" | Outlook + Calendar + OneDrive |
| `bastienchabal/gmail-mcp` | ~530 stars (per ChatForest) | Gmail-only |
| GSuite-1 MCP | Mid | Gmail + Calendar |
| `MarimerLLC/calendar-mcp` | **Closest direct competitor** | Multi-tenant, multi-account, M365 + Outlook.com + Workspace — but mail/calendar only, no Teams/Drive/GitHub |
| `agentbuilder-outlook-mcp` | Tiny | Send-mail only |

**Implication.** Long tail of single-vendor MCP servers, very few span
Google + Microsoft + GitHub *and* aggregate across them in one turn.
`calendar-mcp` is the only one with comparable cross-tenant ambitions; it
stops at mail/calendar.

### C. Unified API / integration platforms — SaaS managed

| Platform | Reach | Pricing | Auth model |
|---|---|---|---|
| **Composio** | 500+ apps, native MCP server | $29 → $229/mo → enterprise | Composio holds the OAuth tokens |
| **Pipedream** | 3,000+ APIs / 10,000+ tools, MCP server | Free 100 credits/mo → enterprise | Pipedream holds the tokens |
| **Merge** | Unified APIs (HR, CRM, etc.) | $650/mo for 10 accounts | Merge holds the tokens |
| **Nango** | OAuth infra for agents | Tiered SaaS | Nango holds the tokens |
| **Zapier MCP** | Massive Zapier app catalog | Per-task pricing | Zapier holds the tokens |

**Implication.** These win on breadth and zero-setup, but require *your
tokens to live on their servers*, recurring fees, and rate-limited tiers.
The skill targets exactly the user who refuses that trade.

### D. Skill / plugin marketplaces — distribution channels

- **Anthropic official plugin directory** — 55+ curated plugins (early
  2026), inside Claude Code & Cowork
- **Anthropic skills repo** (`anthropics/skills`) — community
  marketplace.json
- **VoltAgent/awesome-agent-skills** — 1,000+ skills curated, multi-runtime
- **SkillsMP**, **claudemarketplaces.com** — third-party indexes

**Implication.** The December 2025 Agent Skills spec is now an open
standard adopted by Codex CLI and ChatGPT. Distribution surface is
expanding fast — listing in `awesome-agent-skills` and Anthropic's
marketplace are the cheapest reach gains. The skill currently distributes
via npm + manual install only.

### E. Local OAuth / token-broker primitives — apl's neighborhood

- **`apify/mcpc`** — universal MCP CLI client with OAuth 2.1 + OS
  keychain; broader scope than apl but generic, no recipe layer
- **Better Auth 1.5** — OAuth 2.1 provider for MCP servers; building
  blocks, not a product
- **fast-agent / OpenCode** — MCP runtimes with OAuth handling baked in

**Implication.** apl's "BYO Azure/GCP project + local keychain" stance is
unusual. Most MCP-OAuth tooling either holds tokens server-side (SaaS) or
relies on the MCP client to drive the dance. apl + skill is the only
combo that ships a *paired* recipe catalog and broker designed to outlive
any one runtime.

---

## 3. Positioning matrix

```
                      Local-first / BYO         SaaS managed
                      ──────────────────        ─────────────
Single-provider       gmail-mcp,                Composio (per-tool),
                      ms-365-mcp-server         Anthropic connectors

Multi-provider        ◀ all-purpose-data-skill  Pipedream, Merge,
+ aggregation         + apl ▶                   Claude Cowork, Work IQ
                      calendar-mcp (mail/cal)
```

The skill occupies the **multi-provider × local-first** quadrant —
sparsely populated and structurally hard to reach for SaaS-funded
competitors (their business model requires holding tokens).

---

## 4. Strengths to lean on

1. **Cross-provider fan-out** — unique outside SaaS. "Two inboxes, one
   query" is hard to copy without storing tokens centrally.
2. **GitHub bundled with productivity** — Morning Brief crosses dev +
   comms boundaries. Most competitors are dev-only (Linear/Sentry MCPs)
   or comms-only (Outlook MCP).
3. **Token-frugal defaults** — explicit recipe-level filtering rules.
   Most MCP servers dump 200 tools and let the LLM thrash.
4. **No recurring costs** for personal use. Composio's free tier is
   per-tool-call capped; this is unmetered.
5. **Auth split is durable** — apl can power non-Claude agents (Codex
   already supported; Cursor, Gemini CLI compatible with the SKILL.md
   format).
6. **Production-shaped failure handling** — preflight, handle-selection,
   workflow docs are real, not toy.

---

## 5. Gaps / risks

| Gap | Severity | Note |
|---|---|---|
| Setup friction (`az login`, `gcloud`, manual OAuth client step) | **High** | Composio/Cowork are 1-click; this needs CLI-comfortable users |
| Single-developer project, no enterprise features (audit logs, IT consent, SSO) | **High** | Work IQ wins enterprise by default |
| Discovery — not yet in Anthropic official marketplace or `awesome-agent-skills` | Medium | Easy to fix |
| Smaller API surface than 200-tool MS-365-MCP — recipe-driven means curated, not exhaustive | Medium | Trade-off; positions as "the 80% you actually use" |
| No webhook / event subscription drivers (delta-and-batch documents the surface but agent must drive) | Medium | Briefings stay pull-based |
| Locked to Claude Code / Codex install paths today | Low | SKILL.md format is becoming portable |
| Microsoft 365 Copilot increasingly bundles Claude — Anthropic+MS may eat the official path | Medium | But only on paid Copilot SKUs |
| Slack / Notion / Linear absent | Medium | Those are the next "morning brief" surfaces users expect |

---

## 6. Opportunities

1. **List on Anthropic's official plugin directory + `awesome-agent-skills`.**
   Distribution ROI is the highest-leverage move.
2. **Slack / Notion / Linear recipes** via apl extension — closes the
   Cowork feature gap on the comms side.
3. **First-class Codex / Cursor / Gemini CLI support.** The open Skills
   spec lets one codebase target four runtimes.
4. **`apl` as a standalone product.** The OAuth-broker-with-keychain
   niche is real (mcpc occupies it generically); a Microsoft+Google-
   specific broker with `setup` flows is more polished.
5. **"Self-hosted Composio" narrative.** Clear, accurate, and underserved
   positioning for privacy-conscious teams.
6. **Team mode.** Shared recipe catalog, per-user keychain tokens,
   audit-log emit hook → bridges to enterprise without becoming SaaS.
7. **Webhook-driven Morning Brief** that pushes to Slack/email at 8am —
   moves from on-demand to ambient.

---

## 7. Sources

- [GitHub - VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills)
- [GitHub - anthropics/skills](https://github.com/anthropics/skills)
- [GitHub - anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official)
- [Discover and install prebuilt plugins through marketplaces — Claude Code Docs](https://code.claude.com/docs/en/discover-plugins)
- [MS365 for Claude Code Skill](https://mcpmarket.com/tools/skills/ms365-for-claude-code)
- [Microsoft 365 (softeria/ms-365-mcp-server) — Awesome MCP Servers](https://mcpservers.org/servers/softeria/ms-365-mcp-server)
- [GitHub - elyxlz/microsoft-mcp](https://github.com/elyxlz/microsoft-mcp)
- [GitHub - MarimerLLC/calendar-mcp](https://github.com/MarimerLLC/calendar-mcp)
- [Gmail MCP Server — Awesome MCP Servers](https://mcpservers.org/servers/bastienchabal/gmail-mcp)
- [GSuite MCP](https://mcpmarket.com/server/gsuite-1)
- [Overview of Microsoft MCP Server for Enterprise (Work IQ)](https://learn.microsoft.com/en-us/graph/mcp-server/overview)
- [Anthropic Expands Claude Microsoft 365 Integration for All User Plans — UC Today](https://www.uctoday.com/productivity-automation/anthropic-expands-claude-microsoft-365-integration-for-all-user-plans/)
- [Claude Cowork: Daily Briefing — Petr Vojáček](https://petrvojacek.cz/en/blog/claude-cowork-daily-briefing/)
- [Google Labs CC](https://labs.google/cc/)
- [Composio](https://composio.dev/) and [The Top 5 Unified API Platforms for AI Agents (2026)](https://composio.dev/blog/best-unified-api-platforms)
- [Pipedream](https://pipedream.com/)
- [GitHub - apify/mcpc](https://github.com/apify/mcpc)
- [Better Auth 1.5](https://better-auth.com/blog/1-5)
- [Outlook MCP Servers — ChatForest review](https://chatforest.com/reviews/outlook-mcp-servers/)
- [Daily Briefing Hub — Termo](https://termo.ai/skills/daily-briefing-hub)
