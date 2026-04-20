# Loom System Analysis

> Analysis of the Loom codebase — an AI-powered coding agent built in Rust by Geoffrey Huntley
> (inventor of the ralph loop). This document covers how Loom handles: README lookup tables,
> development guidelines, logging, source control, deployment, analytics, and its modular
> architecture.

---

## 1. README Lookup Tables

The README and `specifications/README.md` use Markdown tables as a structured index — a "lookup table"
pattern that maps each system to its spec file and implementing crates.

The `specifications/README.md` is the canonical index. It's organized into categories, each with a table:

```
| Spec | Code | Purpose |
|------|------|---------|
| analytics-system.md | loom-analytics-core, loom-analytics, loom-server-analytics | Product analytics |
```

This pattern appears across every category: Core Architecture, Observability, LLM Integration,
Configuration & Security, etc. The README itself has a simpler version of the same pattern:

```
| Component | Description |
|-----------|-------------|
| Core Agent | State machine for conversation flow and tool orchestration |
| LLM Proxy  | Server-side proxy architecture - API keys never leave the server |
| ...        | ...                                                           |
```

The key insight: specs are treated as the source of truth for intent, code is the source of truth
for reality. The AGENTS.md explicitly says: "Assume NOT implemented. Many specs describe planned
features that may not yet exist in the codebase. Check the codebase first."

---

## 2. Development Guidelines (AGENTS.md)

The `AGENTS.md` file is the primary developer/agent guide. Key rules:

### Code Style
- Hard tabs, 2-space width, 100 char line width (enforced by `rustfmt.toml`)
- Errors: `thiserror` for error enums, `anyhow` for propagation. Always define `Result<T>` aliases.
- Async: Tokio runtime. `async-trait` for async trait methods.
- Imports: group std → external crates → internal `loom-*` crates.
- Naming: `snake_case` functions/variables, `PascalCase` types, `SCREAMING_CASE` constants.
- No comments unless code is genuinely complex. Copyright header required on every file.

### HTTP Clients
Never build `reqwest::Client` directly. Always use `loom-http::{new_client, builder}` for
consistent User-Agent and retry logic.

### Secrets
Use `loom-secret::{Secret, SecretString}` for API keys, tokens, passwords. Access via `.expose()`.
The type auto-redacts in Debug/Display/Serialize/tracing output.

### Instrumentation
```rust
#[instrument(skip(self, secrets, large_args), fields(id = %id))]
```
Always skip secrets in `#[instrument]`. Always skip large args.

### Logging
Use structured logging (`tracing`). Never log secrets directly.

### Testing
Prefer property-based tests (`proptest`) over unit tests when appropriate. Every test must document:
1. Purpose — why it's important
2. Invariant — what property it verifies
3. Context — when this matters

### Svelte 5 (web)
Always use Svelte 5 runes syntax. Never use Svelte 4 patterns.

### Routes
Use `PublicRouter` for unauthenticated routes, `AuthedRouter` for protected routes. When
adding/modifying routes, update authz tests in `tests/authz_*_tests.rs`.

### Database Migrations
All migrations go in `crates/loom-server/migrations/` as numbered SQL files (`NNN_description.sql`).
Never put inline SQL migrations in other crates. After adding migrations, run `cargo2nix-update`
because cargo2nix doesn't track `include_str!` file changes.

### Shared Services Pattern
When multiple code paths do similar things with slight variations, create a shared service with a
request struct that captures the variations, rather than having each caller implement its own logic.

---

## 3. Logging

Loom uses the `tracing` crate throughout for structured, contextual logging.

### Core Pattern
```rust
#[instrument(skip(self, request), fields(model = %self.config.model))]
async fn complete(&self, request: LlmRequest) -> Result<LlmResponse, LlmError> {
    info!("Starting non-streaming completion request");
    // ...
}
```

### Rules
- Use `tracing` macros (`info!`, `warn!`, `error!`, `debug!`) — never `println!` or `eprintln!`
- Always use `#[instrument]` on significant async functions
- Skip secrets and large args in `#[instrument]`: `skip(self, api_key, large_payload)`
- Use `fields(id = %id)` to attach structured context to spans
- Never log secrets directly — the `Secret<T>` type auto-redacts in all output

### Audit Logging (separate system)
The audit system (`loom-server-audit`) is a separate concern from application logging. It uses an
async mpsc queue with pluggable sinks (SQLite, syslog, HTTP webhooks, JSON streams). See section 6
(Analytics) and the audit spec for details.

---

## 4. Source Control (Spool)

Loom has its own version control system called **Spool**, built as a fork of
[jj (Jujutsu)](https://github.com/martinvonz/jj) with tapestry-themed naming.

### Terminology

| jj Term | Spool Term | Meaning |
|---------|------------|---------|
| `.jj` directory | `.spool` | Where thread is wound/stored |
| Change | **Stitch** | Atomic unit of work |
| Commit | **Knot** | Tied-off stitch with message |
| Working copy | **Shuttle** | Active carrier moving through work |
| Conflict | **Tangle** / **Snag** | Threads crossing incorrectly |
| Bookmark | **Pin** | Marker on the thread |
| Rebase | **Rethread** | Moving stitches to new position |
| Squash | **Ply** | Twisting strands together |
| Undo | **Unpick** | Removing stitches |

### CLI Commands
All under `loom spool`:
- `loom spool wind` — init a new spool
- `loom spool stitch` — start a new stitch (jj new)
- `loom spool knot` — tie off with a message (jj commit)
- `loom spool trace` — show history (jj log)
- `loom spool rethread` — rebase stitches
- `loom spool shuttle` — push to remote (jj git push)
- `loom spool unpick` — undo last operation

### Crate Structure
```
crates/
├── loom-common-spool/   # Core library (jj fork), SpoolRepo API
└── loom-cli-spool/      # CLI implementation, command handlers
```

### Git Interoperability
Spool maintains full Git compatibility via colocated mode: `.spool` alongside `.git`, both updated
together. Pins map to Git branches. Stitches become Git commits when shuttled.

### Agent Integration
The Loom agent uses spool for auto-stitching: each tool execution creates a new stitch, enabling
rollback via `unpick` if a tool execution fails.

### Actual Deployment Source Control
For the production deployment itself, source control is just Git. The deploy flow is:
`git push origin trunk` → NixOS auto-update service detects new commits → rebuilds and deploys.

---

## 5. Deployment

Loom deploys to a NixOS server with a fully automated push-to-deploy pipeline.

### Deploy Flow
```
git push origin trunk
    ↓
NixOS auto-update service (runs every 10 seconds)
    ↓
Detects new commit at /var/lib/depot
    ↓
Rebuilds NixOS configuration (includes loom-server, loom-web, etc.)
    ↓
Activates new configuration
```

### Key Commands
```bash
# Deploy
git push origin trunk

# Check status (run on the server, no SSH needed)
sudo systemctl status nixos-auto-update.service
sudo journalctl -u nixos-auto-update.service -f

# Check what's deployed
cat /var/lib/nixos-auto-update/deployed-revision

# Force rebuild
sudo rm /var/lib/nixos-auto-update/deployed-revision
sudo systemctl start nixos-auto-update.service

# Verify deployment
curl -s https://loom.ghuntley.com/health | jq .
sudo systemctl status loom-server
```

### Build System
Two build paths:

**Nix (preferred for production):** Uses `cargo2nix` for reproducible builds with per-crate
caching. Much faster on incremental changes.
```bash
nix build .#loom-cli-c2n
nix build .#loom-server-c2n
nix build .#weaver-image
```

**Cargo (development):** For quick iteration.
```bash
cargo build --workspace
make check  # format + lint + build + test
```

### cargo2nix Workflow
When `Cargo.toml` or `Cargo.lock` changes:
1. Run `cargo2nix-update` to regenerate `Cargo.nix`
2. Commit `Cargo.nix` with the changes
3. This is also required after adding migration files (cargo2nix doesn't track `include_str!`)

### Binary Distribution
The server serves CLI binaries at `/bin/{platform}` for self-update:

| Platform | Endpoint |
|----------|----------|
| Linux x64 | `GET /bin/linux-x86_64` |
| Linux ARM64 | `GET /bin/linux-aarch64` |
| macOS Intel | `GET /bin/macos-x86_64` |
| macOS Apple Silicon | `GET /bin/macos-aarch64` |
| Windows x64 | `GET /bin/windows-x86_64` |

`loom update` downloads the binary for the current platform and atomically replaces itself.

### CI/CD (GitHub Actions)
Build matrix across 5 platforms → package bundle → release upload. Artifacts include per-platform
CLI binaries, server binary, and a `loom-bundle` tarball.

### Container Images
Built via Nix/devenv for reproducibility. Published to registry with `latest`, `v0.x.x`, and
`<sha>` tags.

### Infrastructure
`infra/` contains NixOS modules for the production server:
- `loom-server.nix` — main server service
- `loom-web.nix` — web frontend (nginx)
- `k3s.nix` — Kubernetes for Weaver pods
- `nixos-auto-update.nix` — the auto-deploy service
- `secrets.nix` — SOPS-encrypted secrets

---

## 6. Analytics

Loom has a full PostHog-style product analytics system built in.

### Architecture
Three crates:
- `loom-analytics-core` — shared types (Person, Event, PersonIdentity)
- `loom-analytics` — Rust SDK client with batching
- `loom-server-analytics` — server-side API, storage, identity resolution

Plus a TypeScript SDK: `web/packages/analytics` (`@loom/analytics`).

### Core Concepts

**Person:** A user being tracked (anonymous or identified). Has a `PersonId` and JSON properties.

**PersonIdentity:** Links `distinct_id` values to a Person. Multiple distinct_ids can point to the
same Person (anonymous + identified).

**Event:** A tracked action. Has `event_name`, `properties` (JSON), `distinct_id`, `timestamp`.

**Identity Resolution (PostHog-style):**
1. Anonymous user arrives → SDK generates UUIDv7, stored in localStorage/cookie
2. Events captured with this `distinct_id`
3. User identifies → SDK calls `identify(anonymous_id, user_id)`
4. Server merges: both distinct_ids linked to same Person
5. Future events from either distinct_id resolve to same Person

### API Keys
Two types:
- `loom_analytics_write_*` — write-only, safe for client-side (capture, identify, alias)
- `loom_analytics_rw_*` — read+write, server-side only (also query/export)

### SDK Usage (Rust)
```rust
let client = AnalyticsClient::builder()
    .api_key("loom_analytics_write_xxx")
    .base_url("https://loom.example.com")
    .build()?;

client.capture("button_clicked", "user_123", Properties::new()
    .insert("button_name", "checkout")
).await?;

client.identify("anon_abc123", "user@example.com", Properties::new()
    .insert("plan", "pro")
).await?;
```

### SDK Behavior
- Events queued, flushed every 10s or 10 events (batching)
- Exponential backoff on failure (via `loom-http`)
- Offline: events queued in memory, flushed when online
- `reset()` on logout: generates new anonymous distinct_id

### Web Tracking Helpers
Consistent helper functions in `$lib/analytics`:
```typescript
trackLinkClick('nav_threads', '/threads')
trackButtonClick('create_weaver')
trackFormSubmit('create_org', { org_id: selectedOrg })
trackModalOpen('delete_weaver', { weaver_id: weaver.id })
trackFilterChange('status', 'active')
trackAction('resolve', 'issue', issue.id)
```

### Experiment Integration
Feature flag exposures (from `loom-flags`) are automatically tracked as `$feature_flag_called`
events. The `exposure_logs` table joins with `analytics_person_identities` for experiment analysis.

### Audit System (separate from analytics)
The audit system (`loom-server-audit`) handles security/compliance logging:
- Async mpsc queue (non-blocking, fire-and-forget from handlers)
- Pluggable sinks: SQLite (primary), syslog (RFC 5424), HTTP webhooks, JSON TCP/UDP, file (JSONL/CEF)
- Event enrichment: session context, org context, GeoIP (MaxMind)
- SIEM integration: Splunk, Datadog, QRadar, ArcSight, Elastic
- Severity levels map to RFC 5424 syslog levels
- CEF (Common Event Format) support for enterprise SIEMs

### Log Analysis (Live Log Viewer)
`loom-server-logs` provides a live, queryable log viewer for the admin panel — distinct from the
audit system. It captures the server's own `tracing` output and makes it available via API/SSE.

**How it works:**
- `BroadcastLogLayer` is a `tracing_subscriber` layer that intercepts all log events as they're emitted
- Captured entries are stored in `LogBuffer` — a thread-safe ring buffer (default 10,000 entries)
- Each `LogEntry` has: sequential `id`, `timestamp`, `level` (trace/debug/info/warn/error), `target` (module path), `message`, and structured `fields` (key-value pairs)
- The admin panel can query recent logs and stream new ones in real time via SSE

**Secret redaction:**
`RedactingLayer` and `RedactingWriter` wrap the log output to strip secrets before they reach any sink. This works in conjunction with the `loom-redact` crate (which uses gitleaks patterns to detect secrets) to ensure nothing sensitive appears in logs even if a developer accidentally logs a raw value.

**Crate:** `loom-server-logs`
- `LogBuffer` — ring buffer, thread-safe
- `BroadcastLogLayer` — tracing layer that feeds the buffer and broadcasts to SSE subscribers
- `RedactingLayer` / `RedactingWriter` — secret-stripping wrappers for log output
    .actor(user_id)
    .resource("thread", thread_id.to_string())
    .action("User attempted to access private thread")
    .severity(AuditSeverity::Warning)
    .build();

state.audit.log(entry);  // non-blocking, fire-and-forget
```

---

## 7. Modular Architecture

Loom's modularity is its defining structural characteristic. The entire system is a Cargo workspace
with 30+ crates, each with a single responsibility.

### Naming Convention
Crate names follow a strict pattern: `loom-{layer}-{domain}[-{sub}]`

| Prefix | Layer |
|--------|-------|
| `loom-common-*` | Shared types/utilities used across layers |
| `loom-server-*` | Server-side implementations |
| `loom-cli-*` | CLI-side implementations |
| `loom-tui-*` | Terminal UI components |
| `loom-weaver-*` | Remote execution (Kubernetes) components |
| `loom-wgtunnel-*` | WireGuard tunnel components |

### Dependency Layering
The dependency graph flows strictly upward — lower layers never depend on higher layers:

```
loom-core (bottom — defines interfaces, no implementations)
    ↑
loom-common-* (utilities: http, secret, config, i18n, thread, spool)
    ↑
loom-*-core (domain types: analytics-core, flags-core, sessions-core, etc.)
    ↑
loom-server-llm-* (provider implementations — server-only)
    ↑
loom-server-* (HTTP handlers, business logic)
    ↑
loom-cli-* (CLI commands, client-side logic)
    ↑
loom-cli / loom-tui-app (top — orchestrates everything)
```

**Key constraint:** Provider implementations (Anthropic, OpenAI) live only in server-side crates.
The CLI never has direct access to API keys.

### The Core/Implementation Split Pattern
Every major domain follows this pattern:

| Domain | Core (types) | Implementation | Server handler |
|--------|-------------|----------------|----------------|
| Analytics | `loom-analytics-core` | `loom-analytics` | `loom-server-analytics` |
| Feature Flags | `loom-flags-core` | `loom-flags` | `loom-server-flags` |
| Sessions | `loom-sessions-core` | — | `loom-server-sessions` |
| Crons | `loom-crons-core` | `loom-crons` | `loom-server-crons` |
| Crash | `loom-crash-core` | `loom-crash` | `loom-server-crash` |

The `-core` crate defines types and traits. The implementation crate is the SDK/client. The
`loom-server-*` crate is the HTTP handler + storage.

### Trait-Based Extension Points
New capabilities are added by implementing traits, not modifying existing code:

**New LLM Provider:**
1. Create `loom-server-llm-{provider}` implementing `LlmClient` trait
2. Add to `LlmService` in `loom-server`
3. No client-side changes needed — `ProxyLlmClient` automatically gets access

**New Tool:**
1. Implement `Tool` trait in `loom-tools`
2. Register in `loom-cli`'s `create_tool_registry()`

**New Audit Sink:**
1. Implement `AuditSink` trait
2. Add to sink list in server initialization

### Server-Side LLM Proxy
The most important architectural decision: API keys never leave the server.

```
loom-cli  →  /proxy/{provider}/complete  →  loom-server  →  Anthropic/OpenAI
              (HTTP + SSE stream)              (holds keys)
```

**How it works end-to-end:**

1. CLI creates `ProxyLlmClient::anthropic(server_url)` — a client that speaks HTTP to the server
2. `ProxyLlmClient.complete()` sends a POST to `/proxy/anthropic/complete` (or `/proxy/openai/stream`)
3. Server's `LlmService` receives the request, selects the right provider, and calls the real API using server-stored credentials
4. The provider streams back SSE events → server forwards them as SSE to the CLI
5. CLI receives the stream and processes `LlmEvent` variants (TextDelta, ToolCallDelta, Completed)

**Key properties:**
- `ProxyLlmClient` implements the same `LlmClient` trait as the real providers — the agent state machine doesn't know it's talking through a proxy
- `LlmService` on the server supports multiple providers simultaneously (`has_anthropic()`, `has_openai()`) with separate API keys
- Provider-specific endpoints: `/proxy/anthropic/complete`, `/proxy/anthropic/stream`, `/proxy/openai/complete`, `/proxy/openai/stream`
- Audit logging happens at the proxy layer — every LLM request is logged server-side
- Adding a new provider requires only a new `loom-server-llm-{provider}` crate + registration in `LlmService` — zero client changes needed

**Crates involved:**
- `loom-core` — defines the `LlmClient` trait and `LlmRequest`/`LlmResponse` types
- `loom-server-llm-anthropic`, `loom-server-llm-openai`, etc. — real provider clients (server-only)
- `loom-server-llm-service` — `LlmService` wrapping all providers
- `loom-server-llm-proxy` — `ProxyLlmClient` used by the CLI

### Agent State Machine
The core agent is an explicit state machine in `loom-core`:

```
WaitingForUserInput
    → CallingLlm (on UserInput)
    → ProcessingLlmResponse (on LlmEvent::Completed)
    → ExecutingTools (if tool calls present)
    → PostToolsHook (after tools complete — triggers auto-commit, etc.)
    → CallingLlm (loop back with tool results)
    → Error (on failure, with retry count)
    → ShuttingDown
```

State transitions are driven by `AgentEvent` and produce `AgentAction` for the caller. This
separation means the state machine is pure logic — the caller handles I/O.

### TUI Widget System
The terminal UI follows the same modularity: each widget is its own crate.
- `loom-tui-core` — base traits
- `loom-tui-theme` — design tokens
- `loom-tui-component` — base component
- `loom-tui-widget-*` — individual widgets (thread-list, spinner, markdown, input-box, etc.)
- `loom-tui-app` — composes widgets into the full TUI
- `loom-tui-storybook` — visual snapshot testing for widgets

### Configuration Layering
Configuration follows XDG Base Directory spec with 6 precedence levels:

```
CLI args (highest)
    ↓ env vars (LOOM_*)
    ↓ workspace config (.loom/config.toml)
    ↓ user config (~/.config/loom/config.toml)
    ↓ system config (/etc/loom/config.toml)
    ↓ built-in defaults (lowest)
```

Scalar values: higher precedence replaces lower. Tables: deep merge. Arrays: replace entirely.

### Feature Flags System
Runtime feature toggles with two tiers:
- **Platform flags** — super admin managed, override org flags globally
- **Organization flags** — org admin managed, per-environment (dev/staging/prod)

**Core entities:**
- `Flag` — has a key (`checkout.new_flow`), multiple `Variant`s (control/treatment_a), and a default variant
- `FlagConfig` — per-environment config: enabled/disabled + which strategy to use
- `Strategy` — reusable rollout rules: attribute conditions (plan == "pro"), geographic targeting, percentage rollout (0-100%), and scheduled gradual rollouts
- `KillSwitch` — emergency shutoff that overrides all linked flags immediately; requires an activation reason; manual reset only
- `Environment` — dev/prod auto-created per org; org admins can add more
- `SdkKey` — client-side (`loom_sdk_client_*`) or server-side (`loom_sdk_server_*`), scoped to one environment

**Evaluation order:**
1. Flag exists? → else return SDK default
2. Enabled in this environment? → else return default variant (reason: Disabled)
3. Active kill switch linked to this flag? → return default (reason: KillSwitch)
4. Prerequisites met? → else return default (reason: Prerequisite)
5. Strategy conditions match + percentage hash passes? → return strategy variant
6. No strategy / conditions not met → return default variant

Percentage hashing uses murmur3 on `"{flag_key}.{user_id}"` for sticky, consistent assignment.

**Real-time updates via SSE:**
Clients connect to `GET /api/flags/stream` with their SDK key. On connect they receive an `init` event with full flag state. Subsequent `flag.updated`, `killswitch.activated`, and `heartbeat` events are pushed as flags change. SDKs cache locally and reconnect with exponential backoff.

**Experiment integration:**
Every flag evaluation can log an `ExposureLog` entry (deduplicated per context hash per hour). These join with `analytics_person_identities` to compute experiment conversion rates — which variant a user saw vs. what actions they took.

**Crates:**
- `loom-flags-core` — shared types (Flag, Strategy, KillSwitch, EvaluationContext, EvaluationResult)
- `loom-flags` — Rust SDK client with local cache + SSE connection
- `loom-server-flags` — HTTP handlers, evaluation engine, SSE broadcaster, GeoIP resolution
- `web/packages/flags` — TypeScript SDK (`@loom/flags`)

### Weaver (Remote Execution)
Weavers are ephemeral Kubernetes pods that run Loom REPL sessions remotely. The modular structure:
- `loom-server-weaver` — K8s pod provisioning
- `loom-server-k8s` — Kubernetes API client
- `loom-wgtunnel-*` — WireGuard tunnel for SSH/TCP access to pods
- `loom-weaver-ebpf` + `loom-weaver-audit-sidecar` — eBPF syscall auditing sidecar
- `loom-weaver-secrets` — SPIFFE-style identity and secret injection

---

## Summary

| Topic | How Loom Does It |
|-------|-----------------|
| **README lookup tables** | Markdown tables in `specifications/README.md` mapping spec → code → purpose |
| **Dev guidelines** | `AGENTS.md` — code style, patterns, commands, deployment, testing rules |
| **Logging** | `tracing` crate throughout; `#[instrument]` on async fns; secrets auto-redact via `Secret<T>` |
| **Log analysis** | `loom-server-logs`: `BroadcastLogLayer` captures tracing output into a ring buffer; live SSE stream to admin panel; `RedactingLayer` strips secrets |
| **Source control** | Spool (jj fork with tapestry naming); Git for actual repo; push-to-deploy via trunk |
| **Deployment** | `git push origin trunk` → NixOS auto-update service → Nix rebuild; cargo2nix for reproducibility |
| **Analytics** | PostHog-style system: `loom-analytics-core/analytics/server-analytics`; identity resolution; experiment integration |
| **Feature flags** | Two-tier (platform/org); per-environment; strategies with conditions + percentage + schedule; kill switches; SSE real-time updates; exposure tracking for A/B experiments |
| **LLM proxy** | All LLM calls proxied through server; `ProxyLlmClient` on CLI implements same `LlmClient` trait; API keys server-side only; SSE stream forwarded back to CLI |
| **Modularity** | 30+ crates; strict naming convention; dependency layering; trait-based extension; core/impl/server split pattern |
