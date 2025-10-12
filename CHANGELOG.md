# Changelog

All notable changes to the XiansAi Platform Community Edition will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

