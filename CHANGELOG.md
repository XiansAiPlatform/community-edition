# Changelog

All notable changes to the XiansAi Platform Community Edition will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

