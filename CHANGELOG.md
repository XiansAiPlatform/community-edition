# Changelog

All notable changes to the XiansAi Platform Community Edition will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v3.36.0] - 2026-08-14

> **Overview**: This release strengthens **user identity and authority resolution** (including shared-email / linked-identity cases), adds **permanent user deletion** and richer **agent lifecycle controls** in Agent Studio (restart / redeploy), and improves **message roundtrip performance**. It also hardens auth dependencies and enforces **lowercase tenant IDs** on create.

### 🚀 New Features

- **Linked identity & authority resolution**: User identity is resolved more reliably across Admin, User, and Agent APIs when emails are shared or linked across providers. Role, tenant, and ownership lookups stay consistent; ownership transfer and ambiguous email matches require a concrete user ID.
- **Permanent user deletion**: SysAdmins can hard-delete user accounts via Admin API (`DELETE /api/v1/admin/users/{userId}`), with guards against self-deletion and removing the last enabled SysAdmin. A user-deletion webhook event is emitted. Agent Studio exposes this on `/system-admin/users`.
- **Add existing users by user ID**: Tenant admins can add an already-existing account to a tenant by user ID (not only by creating a new email-based invite), avoiding ambiguity when multiple accounts share an email.
- **Agent Studio — agent restart & redeploy**: Dashboard actions to restart an agent (deactivate + reactivate with the same settings) and to redeploy, with progress dialogs and toast feedback.
- **Agent activation validation for messaging**: Messaging workflows validate that the target agent activation is active before proceeding, reducing silent failures against deactivated agents.
- **System-scoped agent name protection**: Prevents name conflicts for system-scoped agents so tenant agents cannot collide with reserved system agent names.

### 🔧 Improvements

- **Message roundtrip performance**: Incoming-origin caching, a compound MongoDB index for thread origin lookup, and tighter certificate-validation caching cut database work on hot message paths.
- **Participant-scoped message routing**: Message stream events route by participant group key (normalized participant IDs); `TenantGroupId` was removed from stream events so clients only receive relevant messages.
- **Lowercase tenant IDs**: New tenant IDs must be lowercase at creation (admin create, bootstrap, and seed). Agent Studio’s create-tenant dialog enforces the same rule. Case-insensitive lookup remains for existing IDs; Cosmos DB tenant creation no longer relies on MongoDB collation.
- **OIDC settings — SysAdmin only**: OIDC configuration endpoints and Agent Studio OIDC UI are restricted to system administrators.
- **Agent Studio — logs**: Simplified logs page with stronger filtering and stream grouping by agent / activation / workflow.
- **Agent Studio — UX**: Sidebar expand-on-navigate when collapsed; consistent `PageLoader` across the dashboard; quicker agent settings links (feedback, secrets, schedules); backend-unavailable screen includes sign-out to switch accounts; user approval status locking for non–SysAdmin self-edits.
- **Admin user management**: Richer user detail fields (provider authority, lockout metadata, timestamps) and improved Admin API key / auth validation.
- **Logging privacy**: Stronger user ID redaction in server logs.

### 🐛 Bug Fixes

- **Participant thread leak**: Fixed a participant/thread leak that could leave orphaned conversation state (backported from the 3.34.x line).
- **Cosmos DB tenant creation**: Replaced collation-based case-insensitive tenant lookup with an exact match plus anchored regex so tenant create works on Azure Cosmos DB for MongoDB.

### ⚠️ Breaking Changes

- **New tenant IDs must be lowercase**: Creating a tenant with mixed-case or uppercase IDs now returns `400` with the accepted form. Existing tenants are unaffected; update any automation that creates tenants.
- **Ownership transfer / participant assignment by user ID**: When an email maps to more than one account, Admin APIs reject ambiguous email-based ownership transfer or participant lookup — pass the target **user ID**.
- **OIDC configuration access**: Non–SysAdmin callers can no longer read or modify OIDC provider settings.
- **Message stream event shape**: Clients that depended on `TenantGroupId` on message stream events should switch to the participant-scoped group key.

### 🔒 Security Updates

- **Agent Studio — NextAuth email homoglyph bypass**: Patched Auth.js/NextAuth email normalizer account-takeover issue (GHSA-7rqj-j65f-68wh).
- **Agent Studio — Next.js auth bypass**: Upgraded Next.js to address App Router / Turbopack middleware authentication bypass (CVE-2026-64642).
- **Agent Studio — nanoid DoS**: Pinned/upgraded transitive `nanoid` against infinite-loop in `customAlphabet` with negative size (CVE-2026-67213).
- **Agent Studio — credential gitignore**: Added SSH / private-key patterns to `.gitignore`.
- **Server — OIDC & Admin API**: SysAdmin-only OIDC config; tighter Admin API key and authentication validation.

### 📋 Migration Guide

#### From v3.35.0 to v3.36.0

1. Stop the platform:
  ```bash
   ./stop-all.sh
  ```
2. Pull the latest community-edition configuration and release notes:
  ```bash
   git pull origin main
  ```
3. Start with the new image tag:
  ```bash
   ./start-all.sh -v v3.36.0
  ```
4. **Tenant creation scripts**: Ensure any automated tenant IDs are lowercase before create.
5. **Admin integrations**: Prefer user IDs (not emails) for ownership transfer and for adding existing users to tenants when emails may collide.
6. **Custom stream clients**: If you consume message SSE / hub events and used `TenantGroupId`, update to participant-scoped group keys.
7. **OIDC admins**: Confirm OIDC provider management is performed by SysAdmin accounts only.

No database migration is required for a standard upgrade. `XiansAi.Lib` has no changes in this release relative to v3.35.0.

---

**Full Changelog**: [https://github.com/XiansAiPlatform/community-edition/compare/v3.35.0...v3.36.0](https://github.com/XiansAiPlatform/community-edition/compare/v3.35.0...v3.36.0)  
**Component changelogs**: [XiansAi Server](https://github.com/XiansAiPlatform/XiansAi.Server/compare/v3.35.0...v3.36.0) · [Agent Studio](https://github.com/XiansAiPlatform/agent-studio/compare/v3.35.0...v3.36.0) · [XiansAi.Lib](https://github.com/XiansAiPlatform/XiansAi.Lib/compare/v3.35.0...v3.36.0)  
**Docker Images**: `v3.36.0` on Docker Hub (`99xio/`*)  
**Documentation**: [XiansAi Docs](https://xiansaiplatform.github.io/XiansAi.Docs/)

## [v3.35.0] - 2026-07-27

> **Overview**: This release adds **self-service agent webhook management**, **tenant metadata** (including encrypted secrets), and **enhanced agent activation APIs**. Agent Studio gains **Azure AD B2C custom-domain authentication**, dashboard and log UX improvements, plus security hardening.

### 🚀 New Features

- **Self-service agent webhooks**: Certificate-authenticated agents can create, list, and delete their own inbound (builtin) webhooks via new Agent API endpoints — no Agent Studio or admin API required. The .NET SDK exposes this as `agent.Webhooks` (`CreateAsync`, `ListAsync`, `DeleteAsync`).
- **Tenant metadata**: Tenants can store an optional metadata list (key/value/type). Secret values are encrypted at rest (AES-256-GCM) and are only decryptable via SysAdmin Admin API endpoints; general tenant payloads never expose decrypted secrets.
- **Enhanced agent activation APIs**: New activation lifecycle endpoints for listing, creating, activating, and deactivating agent activations, with an `ActivateAgentRequest` model for optional workflow configuration. The .NET SDK adds activation management helpers (`ActivationExistsAsync`, `GetActivationStatusAsync`, `TenantAgents`).
- **HITL task action metadata (Lib)**: Task actions can carry optional metadata, and metadata can be updated on HITL tasks without completing them (`UpdateMetadata`).
- **Agent Studio — Azure AD B2C**: Support for Azure AD B2C as an auth provider for branded / custom-domain sign-in experiences (new env vars and sign-in UI option).
- **Log stream error count**: Log stream summaries now include an `ErrorCount` field (counts `Error` and `Critical` logs), so clients can spot streams with failures in their history.

### 🔧 Improvements

- **Case-insensitive tenant IDs**: Tenant creation and lookup treat tenant IDs as unique regardless of casing, rejecting duplicates that differ only by case.
- **Clearer invalid workflow identifier errors**: Malformed workflow identifiers now return dedicated, user-friendly API error responses instead of opaque failures.
- **Agent Studio — dashboard & admin UX**: Refactored dashboard layout and platform summary; improved user role management in admin dialogs; task management enhancements on the dashboard.
- **Agent Studio — logs UX**: Better log stream error handling, improved message wrapping/display, and copy-to-clipboard for log messages.
- **Lib — schedule logging**: “Schedule not found” is now logged at debug instead of warning to reduce noise.
- **Architecture documentation**: Constraint catalogue for XiansAi Server and comprehensive architecture docs for Agent Studio.

### ⚠️ Deprecations

- **`SendHandoffAsync` (Lib)**: Marked `[Obsolete]` across MessageActivityExecutor, MessageService, UserMessageContext, and MessageActivities. Prefer the supported handoff / messaging APIs; these methods will be removed in a future version.

### 🔒 Security Updates

- **Agent Studio — health endpoint**: Removed version, environment, and uptime disclosure from `/api/health`.
- **Agent Studio — PostCSS XSS**: Patched transitive PostCSS XSS vulnerability (GHSA-qx2v-qp2m-jg93 / CVE via Next.js dependency chain).
- **Agent Studio — credential gitignore**: Added patterns for common credential and private-key files to reduce accidental secret commits.
- **Tenant secret metadata**: Secret-typed tenant metadata is encrypted at rest and never returned decrypted on general tenant APIs.

### 📋 Migration Guide

#### From v3.34.0 to v3.35.0

1. Stop the platform:
  ```bash
   ./stop-all.sh
  ```
2. Pull the latest community-edition configuration and release notes:
  ```bash
   git pull origin main
  ```
3. Start with the new image tag:
  ```bash
   ./start-all.sh -v v3.35.0
  ```
4. **Optional — Azure AD B2C in Agent Studio**: If you want branded / custom-domain sign-in, configure the Azure AD B2C environment variables described in the Agent Studio Microsoft SSO docs, then restart Studio.
5. **SDK consumers**: If you use `SendHandoffAsync`, plan a migration off the deprecated APIs. To manage webhooks or activations from agent code, use the new `agent.Webhooks` and activation helpers in `XiansAi.Lib`.

No mandatory configuration or database migration is required for a standard upgrade. Tenant metadata and webhook/activation APIs are additive and backward compatible.

---

**Full Changelog**: [https://github.com/XiansAiPlatform/community-edition/compare/v3.34.0...v3.35.0](https://github.com/XiansAiPlatform/community-edition/compare/v3.34.0...v3.35.0)  
**Component changelogs**: [XiansAi Server](https://github.com/XiansAiPlatform/XiansAi.Server/compare/v3.34.0...v3.35.0) · [Agent Studio](https://github.com/XiansAiPlatform/agent-studio/compare/v3.34.0...v3.35.0) · [XiansAi.Lib](https://github.com/XiansAiPlatform/XiansAi.Lib/compare/v3.34.0...v3.35.0)  
**Docker Images**: `v3.35.0` on Docker Hub (`99xio/`*)  
**Documentation**: [XiansAi Docs](https://xiansaiplatform.github.io/XiansAi.Docs/)

## [v3.34.0] - 2026-07-10

> **Overview**: This release introduces **cross-agent Temporal workflow calling**, enabling agents to invoke workflows belonging to other agents. It also adds **pagination to the tenant endpoints** in the Admin API.

### 🚀 New Features

- **Cross-agent Temporal workflow calling**: Agents can now call Temporal workflows owned by other agents, enabling multi-agent orchestration where one agent's workflow can trigger and coordinate workflows across agent boundaries.

### 🔧 Improvements

- **Admin API — paginated tenant endpoints**: The tenant endpoints in the Admin API now return paginated results, improving response times and reducing payload sizes for deployments with a large number of tenants.

### ⚠️ Breaking Changes

- **Admin API tenant endpoints**: Clients consuming the tenant endpoints should be updated to handle the paginated response format and pass pagination parameters where needed.

### 📋 Migration Guide

#### From v3.33.0 to v3.34.0

1. Stop the platform:
  ```bash
   ./stop-all.sh
  ```
2. Pull the latest community-edition configuration and release notes:
  ```bash
   git pull origin main
  ```
3. Start with the new image tag:
  ```bash
   ./start-all.sh -v v3.34.0
  ```
4. If you have custom integrations against the Admin API tenant endpoints, update them to handle paginated responses.

No configuration changes are required for this release.

---

**Full Changelog**: [https://github.com/XiansAiPlatform/community-edition/compare/v3.33.0...v3.34.0](https://github.com/XiansAiPlatform/community-edition/compare/v3.33.0...v3.34.0)  
**Component changelogs**: [XiansAi Server](https://github.com/XiansAiPlatform/XiansAi.Server/compare/v3.33.0...v3.34.0)  
**Docker Images**: `v3.34.0` on Docker Hub (`99xio/`*)  
**Documentation**: [XiansAi Docs](https://xiansaiplatform.github.io/XiansAi.Docs/)

## [v3.33.0] - 2026-07-06

> **Overview**: This release adds **agent template management** to Agent Studio for system administrators, along with **role-based user filtering** in tenant user management.

### 🚀 New Features

- **Agent Studio — agent template management for system admins**: System administrators can now promote existing agents to reusable templates, and manage them from the new **Templates** section in the sidebar (under `/system-admin/agent-templates`).
- **Agent Studio — user filtering by role**: The user management interface now includes a role filter, letting system administrators filter users by specific roles — including `SysAdmin` when viewing in All Tenants mode. The role filter resets when the tenant selection changes, so the available role options always match the selected tenant.

### 📋 Migration Guide

#### From v3.32.0 to v3.33.0

1. Stop the platform:
  ```bash
   ./stop-all.sh
  ```
2. Pull the latest community-edition configuration and release notes:
  ```bash
   git pull origin main
  ```
3. Start with the new image tag:
  ```bash
   ./start-all.sh -v v3.33.0
  ```

No configuration changes are required for this release.

---

**Full Changelog**: [https://github.com/XiansAiPlatform/community-edition/compare/v3.32.0...v3.33.0](https://github.com/XiansAiPlatform/community-edition/compare/v3.32.0...v3.33.0)  
**Component changelogs**: [Agent Studio](https://github.com/XiansAiPlatform/agent-studio/compare/v3.32.0...v3.33.0)  
**Docker Images**: `v3.33.0` on Docker Hub (`99xio/`*)  
**Documentation**: [XiansAi Docs](https://xiansaiplatform.github.io/XiansAi.Docs/)

## [v3.32.0] - 2026-07-04

> **Overview**: This release focuses on **security hardening of Agent Studio**, tightening tenant access control and route authorization across the application. It also improves the community edition startup flow so existing Agent Studio login credentials are reused instead of re-prompted on every run.

### 🔒 Security Updates

- **Agent Studio — tenant access control hardening**: Middleware now restricts access to settings and knowledge routes based on role capabilities (requiring the `settings:view` capability), with a clarified role-to-capability mapping across TenantUser, TenantParticipantAdmin, and TenantAdmin roles.
- **Agent Studio — server-side authorization on tenant management APIs**: API routes for tenant management operations (agent activations, knowledge management, and related endpoints) are now guarded with `withParticipantAdmin`, ensuring access control is enforced server-side rather than relying on the client.
- **Agent Studio — authorization checks in CI**: A new `check:auth` script verifies route authorization coverage, helping prevent unprotected routes from being introduced.

### 🔧 Improvements

- **Startup — existing local login is reused**: `start-all.sh` now detects an already-configured Agent Studio local login (`LOCAL_AUTH_USERS`) and skips the admin account setup prompts, keeping your existing credentials instead of asking on every run. Explicitly providing `ADMIN_EMAIL` / `ADMIN_PASSWORD` via `.env` still overrides the existing setup.

### 📚 Documentation

- **Agent Studio authorization model**: Documentation now clarifies the role-capability mapping and the importance of server-side tenant resolution.

### 📋 Migration Guide

#### From v3.31.0 to v3.32.0

1. Stop the platform:
  ```bash
   ./stop-all.sh
  ```
2. Pull the latest community-edition configuration and release notes:
  ```bash
   git pull origin main
  ```
3. Start with the new image tag:
  ```bash
   ./start-all.sh -v v3.32.0
  ```
4. Verify that users with restricted roles no longer have access to settings and knowledge routes unless they hold the `settings:view` capability. Adjust role assignments in Agent Studio if any users need broader access.

---

**Full Changelog**: [https://github.com/XiansAiPlatform/community-edition/compare/v3.31.0...v3.32.0](https://github.com/XiansAiPlatform/community-edition/compare/v3.31.0...v3.32.0)  
**Component changelogs**: [Agent Studio](https://github.com/XiansAiPlatform/agent-studio/compare/v3.31.0...v3.32.0)  
**Docker Images**: `v3.32.0` on Docker Hub (`99xio/`*)  
**Documentation**: [XiansAi Docs](https://xiansaiplatform.github.io/XiansAi.Docs/)

## [v3.31.0] - 2026-07-04

> **Overview**: This release focuses on the **Community Edition** deployment experience, tightening the setup and startup flow so the platform runs smoothly with **Agent Studio** as the primary interface. It continues the move away from the now-deprecated Xians UI, with configuration, scripts, and documentation aligned around Agent Studio.

### 🔧 Improvements

- **Community Edition — smoother Agent Studio experience**: Deployment configuration, environment files, scripts, and documentation have been refined so the community edition works cleanly with Agent Studio instead of the deprecated Xians UI.
- **Startup — health checks and fail-fast behavior**: `start-all.sh` now waits for PostgreSQL, Temporal, the XiansAi Server, and Agent Studio to become healthy, and aborts with clear guidance when a dependency fails instead of continuing in a broken state.
- **Startup — guided admin account setup**: Administrator email and Agent Studio login password are now prompted for interactively (with an option to auto-generate the password), and the final output clearly points users to sign in to Agent Studio.
- **Startup — clearer bootstrap recovery**: When the platform is already bootstrapped (HTTP 409) but no `XIANS_APIKEY` is present, startup now explains exactly how to recover (restore the key, mint a new one from Agent Studio, or reset the platform) and aborts rather than launching a Studio that cannot reach the server.
- **Configuration — host port overrides**: Added `SERVER_EXTERNAL_PORT` and `STUDIO_EXTERNAL_PORT` to control host-side port mappings, plus optional `SERVER_IMAGE` / `STUDIO_IMAGE` overrides for running locally built images.

### 🐛 Bug Fixes

- **Certificate generation on OpenSSL 3.x**: The root CA temporary key is no longer encrypted with `-des3`, avoiding a PKCS#8 passphrase-prompt failure under OpenSSL 3.x. Only the exported PFX remains password-protected.
- **Agent Studio health check**: The container health check now targets `127.0.0.1` to reliably resolve inside the container.
- **Secrets — shared PostgreSQL credentials**: `create-secrets.sh` now reuses existing database credentials when the Postgres volume is already present, preventing credential mismatches on re-runs.

### ⚠️ Breaking Changes

- **Agent Studio moved to port 3001**: Agent Studio is now served on `http://localhost:3001` (previously `3000`). Update bookmarks, `NEXTAUTH_URL`, and any OAuth redirect URIs accordingly (e.g. `http://localhost:3001/api/auth/callback/<provider>`).
- **LLM credentials managed in-app**: LLM provider API keys are configured in Agent Studio's platform settings rather than via `server/.env.local`. Remove reliance on the `Llm__ApiKey` environment variable.

### 📋 Migration Guide

#### From v3.30.0 to v3.31.0

1. Stop the platform:
  ```bash
   ./stop-all.sh
  ```
2. Pull the latest community-edition configuration and release notes:
  ```bash
   git pull origin main
  ```
3. Update your environment configuration:
   - Set `NEXTAUTH_URL=http://localhost:3001` in `studio/.env.local` (see `studio/.env.example`).
   - Update any OAuth redirect URIs registered with your provider to use port `3001`.
   - Optionally set `SERVER_EXTERNAL_PORT` / `STUDIO_EXTERNAL_PORT` in `.env.local` if you need different host ports.
4. Start with the new image tag:
  ```bash
   ./start-all.sh -v v3.31.0
  ```
5. Sign in to Agent Studio at `http://localhost:3001` and configure your LLM provider and API key in the platform settings (no server environment variable required).
6. For .NET agents/SDKs using **XiansAi.Lib**, update to package version `3.31.0` after publish completes.

### 📚 Documentation

- Updated `README.md`, `docs/SETUP_GUIDE.md`, and `docs/TROUBLESHOOTING.md` to reflect the new Agent Studio port (`3001`) and the in-app LLM provider configuration.

---

**Full Changelog**: [https://github.com/XiansAiPlatform/community-edition/compare/v3.30.0...v3.31.0](https://github.com/XiansAiPlatform/community-edition/compare/v3.30.0...v3.31.0)  
**Component changelogs**: [Server](https://github.com/XiansAiPlatform/XiansAi.Server/compare/v3.30.0...v3.31.0) · [Lib](https://github.com/XiansAiPlatform/XiansAi.Lib/compare/v3.30.0...v3.31.0) · [Agent Studio](https://github.com/XiansAiPlatform/agent-studio/compare/v3.30.0...v3.31.0)  
**Docker Images**: `v3.31.0` on Docker Hub (`99xio/`*)  
**Documentation**: [XiansAi Docs](https://xiansaiplatform.github.io/XiansAi.Docs/)

## [v3.30.0] - 2026-07-03

### 🚀 New Features

- **Server — event publishing via webhook**: The server can now publish platform events to an external endpoint by configuring a webhook URL, enabling outbound integrations and notifications to third-party systems.
- **Agent Studio — multiple file upload**: Agent Studio now supports uploading and handling multiple files at once, streamlining workflows that involve attaching several documents or assets.
- **Agent Studio — local authentication**: Added a local authentication capability to Agent Studio, allowing sign-in without an external identity provider for simpler local and self-hosted deployments.

### 🔧 Improvements

- **Community Edition — reorganized around Agent Studio**: The community edition has been cleaned up and reorganized to use Agent Studio as the primary interface instead of the Xians UI, delivering a single, unified experience. Deployment configuration, environment files, and scripts have been updated accordingly.
- **Developer Experience**: Simplified setup and configuration following the removal of legacy components, reducing the number of services and moving parts required to run the platform.

### 🧹 Cleanups

- **Removed Xians UI support**: The Xians UI has been removed. Its functionality is now fully covered by Agent Studio, which is the recommended and only supported interface going forward.
- **Removed Public API on server**: The server's Public API has been removed as part of consolidating and streamlining the platform's surface area.

### ⚠️ Breaking Changes

- **Xians UI removed**: Deployments and integrations that depended on the Xians UI must migrate to Agent Studio. The `xiansai-ui` image and related configuration are no longer part of the community edition.
- **Public API removed**: Clients relying on the server's Public API must migrate to the supported APIs. Any integrations using the Public API endpoints will need to be updated.

### 📋 Migration Guide

#### From v3.29.0 to v3.30.0

1. Stop the platform:
  ```bash
   ./stop-all.sh
  ```
2. Pull the latest community-edition configuration and release notes:
  ```bash
   git pull origin main
  ```
3. Migrate your environment configuration:
   - The Xians UI environment file (`ui/.env.example`) has been removed. Use the new Agent Studio configuration in `studio/.env.example` as the reference for your `studio/.env.local`.
   - Remove any Xians UI–specific configuration and image references from custom deployments.
4. Start with the new image tag:
  ```bash
   ./start-all.sh -v v3.30.0
  ```
5. For custom deployments, update image references:
  - `99xio/xiansai-server:v3.30.0`
  - `99xio/agent-studio:v3.30.0`

   Note: `99xio/xiansai-ui` is no longer used.
6. For .NET agents/SDKs using **XiansAi.Lib**, update to package version `3.30.0` after publish completes.
7. **Optional — server event webhook**: To publish platform events to an external endpoint, configure the webhook URL in `server/.env.local`.

---

**Full Changelog**: [https://github.com/XiansAiPlatform/community-edition/compare/v3.29.0...v3.30.0](https://github.com/XiansAiPlatform/community-edition/compare/v3.29.0...v3.30.0)  
**Component changelogs**: [Server](https://github.com/XiansAiPlatform/XiansAi.Server/compare/v3.29.0...v3.30.0) · [Lib](https://github.com/XiansAiPlatform/XiansAi.Lib/compare/v3.29.0...v3.30.0) · [Agent Studio](https://github.com/XiansAiPlatform/agent-studio/compare/v3.29.0...v3.30.0)  
**Docker Images**: `v3.30.0` on Docker Hub (`99xio/`*)  
**Documentation**: [XiansAi Docs](https://xiansaiplatform.github.io/XiansAi.Docs/)

## [v3.29.0] - 2026-06-23

### 🚀 New Features

- **AgentStudio feature parity**: AgentStudio now includes all functionality that was previously only available through the Xians UI. AgentStudio is now the recommended interface for managing and interacting with the platform.
- **Server AdminApi enhancements**: Significant updates to the AdminApi to support the expanded AgentStudio capabilities, providing a more complete and consistent set of administrative operations.

### 🔧 Improvements

- **Performance**: Performance fixes across the server AdminApi and AgentStudio projects for faster and more responsive operations.
- **UI/UX**: AgentStudio reaches full feature coverage, delivering a single, unified experience for all platform workflows.

### 🔒 Security Updates

- Addressed several security issues across the AdminApi and AgentStudio projects.
- Hardened authentication and authorization paths affected by the expanded AgentStudio functionality.

### ⚠️ Deprecations

- **Xians UI**: With AgentStudio now offering complete feature parity, the Xians UI is planned for deprecation in an upcoming release. Users are encouraged to begin transitioning their workflows to AgentStudio.

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/v3.28.0...v3.29.0  
**Docker Images**: Available with tag `v3.29.0`  
**Documentation**: See updated documentation in repository

## [v3.28.0] - 2026-06-04

### 🚀 New Features

- **OIDC — Azure AD SysAdmin sync**: Automatically promote or revoke SysAdmin based on Azure AD / Entra ID group membership on every login. Configure `Oidc__AdminGroupIds` with a comma-separated list of group Object IDs; the server checks `groups` and `roles` claims and keeps `IsSysAdmin` in sync ([#407](https://github.com/XiansAiPlatform/XiansAi.Server/pull/407))
- **Webhook header forwarding**: Builtin webhook requests now forward inbound HTTP headers to agent workers via `WebhookContext.Metadata`, enabling integrations with providers such as GitHub and Azure DevOps ([#406](https://github.com/XiansAiPlatform/XiansAi.Server/pull/406), [#100](https://github.com/XiansAiPlatform/XiansAi.Lib/pull/100))
- **Slack app integration — outbound messaging**: Agents can send messages back to Slack with Markdown-to-Slack formatting via `MarkdigSlackConverter`; activation-based app integration lookup supports agent-initiated Slack replies ([#405](https://github.com/XiansAiPlatform/XiansAi.Server/pull/405))
- **Agent Studio — system admin tenants**: New System Admin tenants page with create, edit, delete, enable/disable, and search for platform tenants

### 🔧 Improvements

- **XiansAi.Lib — message-handling performance**: Broad quick-win optimizations across the per-message hot path — HTTP connection pooling in `SecureApi`, cached `JsonSerializerOptions` and reflection lookups, parallelized flow-message dispatch, compiled regex patterns, bounded log queue to prevent OOM during outages, and reduced eager JSON serialization in log lines ([#99](https://github.com/XiansAiPlatform/XiansAi.Lib/pull/99))
- **Server — conversation change-stream reliability**: Processed-event tracking deduplicates conversation messages handled by `MongoChangeStreamService`, avoiding duplicate processing on retries
- **Agent Studio**: Enhanced agent heartbeat polling and conversation page behaviour; simplified message sending and file upload logic

### 🐛 Bug Fixes

- **Server**: `MongoChangeStreamService` now resolves the processed-event repository lazily, reducing unnecessary resource use during message processing

### 📋 Migration Guide

#### From v3.27.0 to v3.28.0

1. Stop the platform:
  ```bash
   ./stop-all.sh
  ```
2. Pull the latest community-edition configuration and release notes:
  ```bash
   git pull origin main
  ```
3. Start with the new image tag (or run your usual publish → release flow first, then):
  ```bash
   ./start-all.sh -v v3.28.0
  ```
4. For custom deployments, update image references:
  - `99xio/xiansai-server:v3.28.0`
  - `99xio/xiansai-ui:v3.28.0`
  - `99xio/agent-studio:v3.28.0`
5. For .NET agents/SDKs using **XiansAi.Lib**, update to package version `3.28.0` after publish completes.
6. **Optional — Azure AD SysAdmin groups**: To enable automatic SysAdmin promotion from Entra ID groups, set in `server/.env.local`:
  ```bash
   Oidc__AdminGroupIds=<group-object-id-1>,<group-object-id-2>
  ```
   Leave unset to keep existing manual SysAdmin assignment behaviour.

---

**Full Changelog**: [https://github.com/XiansAiPlatform/community-edition/compare/v3.27.0...v3.28.0](https://github.com/XiansAiPlatform/community-edition/compare/v3.27.0...v3.28.0)  
**Component changelogs**: [Server](https://github.com/XiansAiPlatform/XiansAi.Server/compare/v3.27.0...v3.28.0) · [UI](https://github.com/XiansAiPlatform/XiansAi.UI/compare/v3.27.0...v3.28.0) · [Lib](https://github.com/XiansAiPlatform/XiansAi.Lib/compare/v3.27.0...v3.28.0) · [Agent Studio](https://github.com/XiansAiPlatform/agent-studio/compare/v3.27.0...v3.28.0)  
**Docker Images**: `v3.28.0` on Docker Hub (`99xio/`*)  
**Documentation**: [XiansAi Docs](https://xiansaiplatform.github.io/XiansAi.Docs/)

## [v3.27.0] - 2026-05-19

### 🚀 New Features

- **Message feedback (platform-wide)**: Rate and comment on agent messages in Agent Studio, the Admin/Developer UI, and via new Server APIs for submitting and retrieving feedback ([#402](https://github.com/XiansAiPlatform/XiansAi.Server/pull/403), [#104](https://github.com/XiansAiPlatform/XiansAi.UI/pull/105), [#50](https://github.com/XiansAiPlatform/agent-studio/pull/36))
- **Admin UI — tenant & organization**: Improved tenant management, header organization context, and searchable organization selection in the Manager portal ([#101](https://github.com/XiansAiPlatform/XiansAi.UI/pull/101)–[#103](https://github.com/XiansAiPlatform/XiansAi.UI/pull/103))
- **Agent Studio — logs**: Auto-refresh for the logs view with countdown indicator and clearer log level badges
- **Agent Studio — knowledge**: Refined knowledge item detail UI, dropdown layout, and descriptions

### 🔧 Improvements

- **Admin UI**: Simplified bulk workflow termination and schedule management
- **Agent Studio**: Theme toggle with tooltip and accessibility improvements; clearer expand/collapse for log entries; improved chat input readability
- **XiansAi.Lib**: Refactored certificate parsing and validation for clarity and maintainability ([#96](https://github.com/XiansAiPlatform/XiansAi.Lib/pull/96))
- **Release tooling**: `XiansAi.Otel.Lib` added to `publish.sh`, `workflow-monitor.sh`, and default asset repos in `release.sh` for coordinated platform releases

### 🐛 Bug Fixes

- **Agent Studio**: Knowledge item detail mode and description copy corrections
- **XiansAi.Lib**: Certificate handling edge cases addressed in parser/validator refactor

### 🔒 Security Updates

- **XiansAi.Lib**: Bumped `OpenTelemetry.Api` to 1.15.3 to address [CVE-2026-40894](https://github.com/XiansAiPlatform/XiansAi.Lib/commit/b81f820)

### 📋 Migration Guide

#### From v3.26.0 to v3.27.0

1. Stop the platform:
  ```bash
   ./stop-all.sh
  ```
2. Pull the latest community-edition configuration and release notes:
  ```bash
   git pull origin main
  ```
3. Start with the new image tag (or run your usual publish → release flow first, then):
  ```bash
   ./start-all.sh -v v3.27.0
  ```
4. For custom deployments, update image references:
  - `99xio/xiansai-server:v3.27.0`
  - `99xio/xiansai-ui:v3.27.0`
  - `99xio/agent-studio:v3.27.0`
5. For .NET agents/SDKs using **XiansAi.Lib**, update to package version `3.27.0` after publish completes.

---

**Full Changelog**: [https://github.com/XiansAiPlatform/community-edition/compare/v3.26.0...v3.27.0](https://github.com/XiansAiPlatform/community-edition/compare/v3.26.0...v3.27.0)  
**Component changelogs**: [Server](https://github.com/XiansAiPlatform/XiansAi.Server/compare/v3.26.0...v3.27.0) · [UI](https://github.com/XiansAiPlatform/XiansAi.UI/compare/v3.26.0...v3.27.0) · [Lib](https://github.com/XiansAiPlatform/XiansAi.Lib/compare/v3.26.0...v3.27.0) · [Agent Studio](https://github.com/XiansAiPlatform/agent-studio/compare/v3.26.0...v3.27.0)  
**Docker Images**: `v3.27.0` on Docker Hub (`99xio/`*)  
**Documentation**: [XiansAi Docs](https://xiansaiplatform.github.io/XiansAi.Docs/)
## [v3.26.0] - 2026-04-29

### 🚀 New Features

- Mobile optimizations of the Agent Studio
- Conversation performance improvements

### 🎯 What's Next

- Planned features for next release
- Roadmap items in progress
- Community feature requests being considered

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v3.26.0
**Docker Images**: Available with tag `v3.26.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v3.25.0] - 2026-04-26

### 🚀 New Features

- Updated AS logs pages to group the logs by WorkflowId
- Updated the performance pages to show stats like min. max, average, etc. 

### 🎯 What's Next

- Planned features for next release
- Roadmap items in progress
- Community feature requests being considered

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v3.25.0
**Docker Images**: Available with tag `v3.25.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v3.24.0] - 2026-04-22

### 🚀 New Features

- Secrets store in Agent Studio

### 🎯 What's Next

- Planned features for next release
- Roadmap items in progress
- Community feature requests being considered

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v3.24.0
**Docker Images**: Available with tag `v3.24.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v3.23.0] - 2026-04-19

### 🚀 New Features

- Added searching for Tenant filter of UI
- Tenant logo is displayed on AS chat start page

### 🔒 Security Updates

- Enhanced security of AS auth and role management

### Bug fixes

- Logger factory getting reinitiated in LIB

### 🎯 What's Next

- Planned features for next release
- Roadmap items in progress
- Community feature requests being considered

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v3.23.0
**Docker Images**: Available with tag `v3.23.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v3.22.0] - 2026-04-08

### 🚀 New Features

- Lib: When non deterministic error occurs, now the workflow get terminated.
- Agent Studio: New theme Gaia added
- UI: Search field on tenant list

### Bug fixes

- Server: Knowledge with same content throwing duplicate error

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v3.22.0
**Docker Images**: Available with tag `v3.22.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v3.20.0] - 2026-03-30

### 🚀 New Features

- User (Participant) management APIs added to Admin API.
- Participant management functionality added to Agent-Studio.

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v3.20.0
**Docker Images**: Available with tag `v3.20.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v3.16.0] - 2026-03-14

### 🚀 New Features

- Theme configuration of agent-studio from ui/server

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v3.16.0
**Docker Images**: Available with tag `v3.16.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v3.13.0] - 2026-03-01

### 🚀 New Features

- **Feature**: Web hooks on Agenrt Studio
- **Feature**: Temporal Signals on LIB

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v3.13.0
**Docker Images**: Available with tag `v3.13.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v3.11.0] - 2026-02-17

### 🚀 New Features

- This release contains mainly fixes and improvements.

### 🎯 What's Next

- Planned features for next release
- Roadmap items in progress
- Community feature requests being considered

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v3.11.0
**Docker Images**: Available with tag `v3.11.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v2.11.0] - 2025-10-26

### 🚀 New Features

- N/A

### 🔧 Improvements

- **Security Hardning**: on both server and the Lib
- **GitHub Auth Provider Improvements**: Login, Logout improvements.

### 🎯 What's Next

- Planned features for next release
- Roadmap items in progress
- Community feature requests being considered

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v2.11.0
**Docker Images**: Available with tag `v2.11.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v2.10.0] - 2025-10-12

### 🚀 New Features

- **System scoped agent templates**: [read more](https://xiansaiplatform.github.io/XiansAi.PublicDocs/n-encyclopedia/system-scoped-agents/)
- **Scheduled agents**: [Setting up](https://xiansaiplatform.github.io/XiansAi.PublicDocs/4-automation/2-flow-scheduling/)
- **Scheduling SDK**: [SDK](https://xiansaiplatform.github.io/XiansAi.PublicDocs/4-automation/2-scheduling-sdk/)

### 🔧 Improvements

- **UI/UX**: Improved Messaging Playground UI in portal

### 🎯 What's Next

- Planned features for next release
- Roadmap items in progress
- Community feature requests being considered

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v2.10.0
**Docker Images**: Available with tag `v2.10.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v2.9.0] - 2025-10-03

### 🚀 New Features

- **Aget Templates**: Agent Templates that can be deployed system wide common for all tenants

### 🔧 Improvements

- **Multi Tenancy**: Several issues of the multi tenancy implementation is fixed

### ⚠️ Breaking Changes

- **Deployed agents**: Delete your agent definitions and recreate. With this release, portal will not show the old definitions.

### 🎯 What's Next

- Planned features for next release
- Roadmap items in progress
- Community feature requests being considered

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v2.9.0
**Docker Images**: Available with tag `v2.9.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v2.8.0] - 2025-09-28

### 🚀 New Features

- **New Tenant Registration**: Now Signed-In users are able to self provision their own tenants. Available at `/register` on UI Portal.
- **Join a Tenant**: Request to join an existing tenant.  Available at `/register` on UI Portal. Tenant admin can approve requests.

### 🔧 Improvements

- **UI/UX**: Home page look and feel improved.

### 🎯 What's Next

- Planned features for next release
- Roadmap items in progress
- Community feature requests being considered

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v2.8.0
**Docker Images**: Available with tag `v2.8.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v2.7.0] - 2025-09-19

### 🚀 New Features

- **Feature Name**: Brief description of the new feature
- **Another Feature**: Description with more details about implementation

### 🔧 Improvements

- **Community Edition (CE)**: Removed all hard-coded secrets from CE. They are automatically generated now in the first run.
- **Xians.Lib IChatInterceptor**: See Breaking changes below


### ⚠️ Breaking Changes

- **MCPs with KernalModifiers**

   ```dotnet
   public async Task<Kernel> ModifyKernelAsync(Kernel kernel)
   ```

   Should be now take additional parameter

   ```dotnet
   public async Task<Kernel> ModifyKernelAsync(Kernel kernel, MessageThread messageThread)
   ```

### 🎯 What's Next

- Planned features for next release
- Roadmap items in progress
- Community feature requests being considered

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v2.7.0
**Docker Images**: Available with tag `v2.7.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v2.6.0] - 2025-09-10

### 🚀 New Features

- **Ability to limit the max tokens for LLM completion**: [details](https://xiansaiplatform.github.io/XiansAi.PublicDocs/n-encyclopedia/limiting-chat-router-tokens/)
- **Another Feature**: Description with more details about implementation

### 🔧 Improvements

- **Performance**: Agent2Agent message forwarding performance improvements (in process routing capability)
- **Developer Experience**: Agent chat routing and A2A interactions are now unit testable without needing to use temporal.[details](https://xiansaiplatform.github.io/XiansAi.PublicDocs/n-encyclopedia/unit-testing/)

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v2.6.0
**Docker Images**: Available with tag `v2.6.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v2.5.0] - 2025-08-31

### 🚀 New Features

- **Schedule RunAt Start Setting**: In schedules flows, one can specify to run at the start of the workflow execution.
- **Webhooks**: Webhooks can be used to send logs to an external service. [details](https://xiansaiplatform.github.io/XiansAi.PublicDocs/2-agent-communication/17-webhooks/)
- **MCP Support**: MCP Support for LLM agents to be able to use it. [details](https://xiansaiplatform.github.io/XiansAi.PublicDocs/n-encyclopedia/mcp-integration/)

### 🔧 Improvements

- **Logs Handling**: Agents are now sending only ERROR and above logs by default to server. Log retention is reduced from 30days to 15days to reduce the db storage cost. [details](https://xiansaiplatform.github.io/XiansAi.PublicDocs/n-encyclopedia/logging/#step-2-configure-logging)
- **Trim Large Activities**: Large (>10K) inputs and outputs of activities histories are now removed from the database to reduce the db storage cost.

### 🐛 Bug Fixes

- Fixed issue with KeyCloak authentication in UI Portal not letting admin to delete agent definitions.
- Resolved a bug stopping agents sutting down when Ctrl+C is pressed.

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v2.5.0
**Docker Images**: Available with tag `v2.5.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v2.4.0] - 2025-08-22

### 🚀 New Features

- **Delete Conversation**: Delete a conversation from the chat [details](https://github.com/XiansAiPlatform/sdk-web-typescript/blob/main/docs/socket-sdk.md)
- **OIDC for User Authentication**: Add OIDC for user authentication [details](https://xiansaiplatform.github.io/XiansAi.PublicDocs/n-encyclopedia/user-auth-config/)
- **Multiple Agent Workers can be Started on the same Agent**: [details](https://xiansaiplatform.github.io/XiansAi.PublicDocs/n-encyclopedia/scaling-agents/)
- **Document Store**: read and write documents to the document store [details](https://xiansaiplatform.github.io/XiansAi.PublicDocs/3-knowledge/5-document-store/)
- **Welcome Message**: Add a welcome message to the chat [details](https://xiansaiplatform.github.io/XiansAi.PublicDocs/2-agent-communication/12-welcome-msg/)
- **Chat Message Encryption**: Now chat messages are encrypted in the database.

### 🔧 Improvements

- **Performance**: Cached APIKEYs on server for 15 mins to improve performance
- **UI/UX**: User interface and experience enhancements
- **Developer Experience**: HTTPTimeoutSeconds for SemanticKernel is now configurable through `RouterOptions` in LIB.
- **Agent API Key Certificate Generation**: Fixed an inconsistency of the userid writing and reading.
- **MemoryHub instance variable removed from FlowBase**: MemoryHub is a static class now.
- **Removed unused MondoDB indexes**

### ⚠️ Breaking Changes

- **Server Configuration**: `EncryptionKeys__BaseSecret` environment variable is now required with a string value. `EncryptionKeys__BaseSecret` is used to encrypt and decrypt database values.
- **MemoryHub**: See above. Use the Static class instead.

---

**Full Changelog**: https://github.com/XiansAiPlatform/community-edition/compare/vPREVIOUS...v2.4.0
**Docker Images**: Available with tag `v2.4.0`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v2.3.0] - 2025-08-11

# 🚀 New Features

- [RPC calls to the agents](https://xiansaiplatform.github.io/XiansAi.PublicDocs/4-automation/1-external-triggers/)
- [Skip Responses feature](https://xiansaiplatform.github.io/XiansAi.PublicDocs/2-agent-communication/5-skip-llm-response.html)
- [Chat Interceptors](https://xiansaiplatform.github.io/XiansAi.PublicDocs/2-agent-communication/7-chat-interceptors.html)
- [simple LLM completion](https://xiansaiplatform.github.io/XiansAi.PublicDocs/n-encyclopedia/llm-completion/#parameters)
- [Scheduled workflows](https://xiansaiplatform.github.io/XiansAi.PublicDocs/4-automation/2-scheduled-execution/)

## 🐛 Bug Fixes

- Fix the temporal signal limit bug

## ⚠️ Breaking Changes

- none

## [v2.2.0] - 2025-07-29

### 🚀 New Features

- Ability to keep knowledge in local files when developing agents (and automatically uploading to server)

### 🔧 Improvements

- **Performance**: Describe performance improvements
- **UI/UX**: User interface and experience enhancements
- **Developer Experience**: Improvements for developers using the platform

### 🐛 Bug Fixes

- Agent API Key Generation: Fixed the bug where new keys were marked as revoked.
- Issues in Temporal activity proxy generation.

### ⚠️ Breaking Changes

- none

## [v2.1.2] - 2025-07-28

# Release Notes v2.1.2

## 🔧 Improvements

- **Features**
  - Added the capability to generate Agent API Keys without revoking old keys.
  - Implemented RouterOptions in FlowBase to allow for more control over the router.
  - Added TTL for collections conversation_messages (180 days), activity_history (90 days) and logs (30 days).
  - Bot2Bot Message Forward Implementation which allows creating super bot that acts as a router.

- **UI/UX**
  - Portal UI Settings -> User Management features a reorganization of the UI

- **Stability**
  - Fixed issue with overall connection handling in the Server and in the Lib.
  - Improved the indexes on server DB to improve performance.

## 🐛 Bug Fixes

- Fixed issue with server DB connections causing connection Exhausted error in Cosmos

## ⚠️ Breaking Changes

- None

## 🎯 What's Next

- Planned features for next release
- Roadmap items in progress
- Community feature requests being considered

---

**Full Changelog**: https://github.com/flowmaxer-ai/community-edition/compare/vPREVIOUS...v2.1.2
**Docker Images**: Available with tag `v2.1.2`
**Documentation**: See updated documentation in repository

## [v2.1.1] - 2025-07-23

### 🚀 New Features

- N/A

### 🔧 Improvements

- EntraId account conflict gracefully handled in UI

### 🐛 Bug Fixes

- TypeScript SDK Handoff handling bug
- Server Websocket bug of Authorization handling

### ⚠️ Breaking Changes

- N/A


### 🏗️ Infrastructure

- **Docker**: Updated Docker images and configurations
- **Database**: Database improvements and optimizations
- **Monitoring**: Enhanced monitoring and health checks

### 📦 Dependencies

- Updated major dependencies to latest versions
- Security patches for all components
- Performance improvements in dependencies

---

**Full Changelog**: https://github.com/flowmaxer-ai/community-edition/compare/vPREVIOUS...v2.1.1
**Docker Images**: Available with tag `v2.1.1`
**Documentation**: See updated documentation in repository

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

## [v2.1.0] - 2025-07-21

### 🚀 New Features

- **TypeScript SDK**: Added TypeScript SDK for the server API's including
  - Websocket API
  - REST API
  - Server Side Events (SSE)
- **Token Authentication for Agents**: Added token authentication for agents to access the server API's
- **Tenant and User Management**: Added tenant and user management to the portal UI
- **Auto Knowledge Update**: Added auto knowledge update capability to Agent Lib
- **Azure OpenAI**: Added Azure OpenAI support to Agent Lib

### 🔧 Improvements

- **Performance**: Websocket performance improvements
- **Developer Experience**: Agent knowledge base "(CAG)" in a local file system

### 🐛 Bug Fixes

- Fixed several bugs across the platform

### ⚠️ Breaking Changes

- **APIKey Changes**: A new APIKey is required for all User API's

### 📋 Migration Guide

#### From TypeScript AgentSDK to SocketSDK, SseSDK, RestSDK

1. **Step 1**: Follow [documentation](https://github.com/XiansAiPlatform/sdk-web-typescript) to update your code to use the new SDKs

### 🔒 Security Updates

- Updated dependencies with security patches
- Enhanced Auth configuration

### 📚 Documentation

- Updated documentation across the platform

### 🏗️ Infrastructure

- **Docker Compose**: Updated Docker images and configurations
- **Database**: New indexing for faster search

### 📦 Dependencies

- Updated major dependencies to latest versions
- Security patches for all components

### 📝 Known Issues

- Tenant's User Management Usability in Portal Settings is suboptimal. Use System Admin features.

### 🎯 What's Next

- Stabilization of the platform

---

<!-- 
INSTRUCTIONS FOR EDITING THIS TEMPLATE:
1. Replace placeholder text with actual changes
2. Remove sections that don't apply to this release
3. Add specific version numbers and dates where needed
4. Include links to relevant PRs, issues, or documentation
5. Test all code examples and commands
6. Review for clarity and completeness before release
-->

