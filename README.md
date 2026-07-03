# XiansAi Platform - Community Edition

Welcome to the XiansAi Platform Community Edition! This repository provides a simple Docker Compose setup to get you started with the XiansAi platform quickly and easily.

It deploys a minimal stack: **XiansAi Server**, **MongoDB**, **Temporal** (with its own PostgreSQL), and **Agent Studio** (the web console). During startup the platform is automatically bootstrapped to mint your first API key, which is injected into Agent Studio for you.

> **New to the project?** The **[Complete Setup Guide](docs/SETUP_GUIDE.md)** has detailed, step-by-step instructions. This README is a quick overview.

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed on your system
- 8GB of available RAM
- Internet connection to download the Docker images

### Steps

1. **Clone and configure:**

   ```bash
   git clone https://github.com/XiansAiPlatform/community-edition.git
   cd community-edition
   cp .env.example .env
   ```

   Edit `.env` and set at least:
   - `ADMIN_EMAIL` — first administrator; bootstraps the platform and is your Agent Studio login username.
   - `ADMIN_PASSWORD` — password for the Agent Studio local login.

   If `ADMIN_EMAIL` / `ADMIN_PASSWORD` are left blank, `start-all.sh` prompts for them. OAuth (Google/Azure/Visma) is optional — see the [Setup Guide](docs/SETUP_GUIDE.md#sign-in-via-oauth-optional).

2. **Start the platform:**

   ```bash
   ./start-all.sh
   ```

   On first run, once the server is healthy `start-all.sh` bootstraps the platform, prints your **API key**, and stores it in `studio/.env.local` (`XIANS_APIKEY`). Save it — it is shown only once. Allow 2-3 minutes for all services to initialize.

## 🌐 Access the Applications

| Application | URL | Credentials |
|-------------|-----|-------------|
| **Agent Studio** | [http://localhost:3000](http://localhost:3000) | Local login: `ADMIN_EMAIL` / `ADMIN_PASSWORD` |
| **Temporal Web UI** | [http://localhost:8080](http://localhost:8080) | No authentication (local only) |
| **API Documentation** | [http://localhost:5001/api-docs](http://localhost:5001/api-docs) | No authentication required |

## 🛠️ Management Scripts

| Script | Purpose |
|--------|---------|
| `./start-all.sh [options]` | Start the platform (`--help` for options such as `-v <version>`, `--observability`, `--observability-azure`) |
| `./stop-all.sh` | Stop all services |
| `./reset-all.sh [-f]` | Complete reset and cleanup (removes all data) |
| `./pull-latest.sh [-v <version>]` | Pull the latest Docker images from Docker Hub |

View logs with `docker compose logs -f [service-name]` (e.g. `xiansai-server`, `agent-studio`).

For host-file setup, database access, sign-in details, and full options, see the **[Complete Setup Guide](docs/SETUP_GUIDE.md)**.

## 🏗️ Platform Architecture

The XiansAi Platform consists of multiple repositories:

- **XiansAi.Server** — Docker Hub [99xio/xiansai-server](https://hub.docker.com/repository/docker/99xio/xiansai-server/general) · Repo [XiansAi.Server](https://github.com/XiansAiPlatform/XiansAi.Server)
- **Agent Studio** — Docker Hub [99xio/agent-studio](https://hub.docker.com/repository/docker/99xio/agent-studio/general) · Repo [agent-studio](https://github.com/XiansAiPlatform/agent-studio)
- **XiansAi.Lib** — NuGet [XiansAi.Lib](https://www.nuget.org/packages/XiansAi.Lib) · Repo [XiansAi.Lib](https://github.com/XiansAiPlatform/XiansAi.Lib)
- **sdk-web-typescript** — npm [@99xio/xians-sdk-typescript](https://www.npmjs.com/package/@99xio/xians-sdk-typescript) · Repo [sdk-web-typescript](https://github.com/XiansAiPlatform/sdk-web-typescript)
- **community-edition** — [Releases](https://github.com/XiansAiPlatform/community-edition/releases) in this repository

## 📚 Documentation

- **[Agent Development Guide](https://xiansaiplatform.github.io/XiansAi.PublicDocs/)** - Building agents on the platform
- **[Complete Setup Guide](docs/SETUP_GUIDE.md)** - Comprehensive setup instructions
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute to the project
- **[Release Guide](docs/RELEASE_GUIDE.md)** - Release process for maintainers
- **[XiansAi Website](https://xians.ai)**

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. See our [Contributing Guide](CONTRIBUTING.md) for detailed instructions.

## 📄 License

This project is licensed under the MIT License.
