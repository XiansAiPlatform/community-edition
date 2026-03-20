# XiansAi Platform - Community Edition

Welcome to the XiansAi Platform Community Edition! This repository provides a simple Docker Compose setup to get you started with the XiansAi platform quickly and easily.

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed on your system
- Device's host file containing the entry `host.docker.internal -> 127.0.0.1`
- 8GB of available RAM
- Internet connection to download the Docker images

**💡 New to the project?** Check out our **[Complete Setup Guide](docs/SETUP_GUIDE.md)** for detailed step-by-step instructions.

### Getting Started

1. **Clone this repository:**

   ```bash
   git clone https://github.com/XiansAiPlatform/community-edition.git
   cd community-edition
   ```

1. **Configure your environment:**

   ```bash
   # Copy the example environment file
   cp .env.example .env
   ```

   Edit the `.env` file and add your configuration:
   - `OPENAI_API_KEY`: Your OpenAI API key for AI functionality
   - `KEYCLOAK_ADMIN_PASSWORD`: Password for the admin user to login to XiansAi UI

   Example:

   ```bash
   OPENAI_API_KEY=sk-your-openai-api-key-here
   KEYCLOAK_ADMIN_PASSWORD=your-secure-password
   ```

1. **Start the platform:**

   ```bash
   # Start with defaults (latest version, local environment)
   ./start-all.sh

   # Show help for all options
   ./start-all.sh --help
   ```

   **Management scripts:**
   - `./start-all.sh [options]` - Start the platform with optional version/environment
   - `./stop-all.sh` - Stop all services (version-independent)  
   - `./reset-all.sh [options]` - Complete reset and cleanup (removes all data)
   - `./pull-latest.sh [options]` - Pull latest Docker images from DockerHub

6. **Access the applications:**

   > ⏱️ **Startup Time**: Allow 2-3 minutes for all services to fully initialize. Check logs with `docker compose logs -f` if services seem unresponsive.

   ### 🌐 Web Applications

   | Application | URL | Purpose | Credentials |
   |-------------|-----|---------|-------------|
   | **XiansAi Platform** | [http://localhost:3001](http://localhost:3001) | Main AI platform interface | `admin` / `KEYCLOAK_ADMIN_PASSWORD` |
   | **Temporal Web UI** | [http://localhost:8080](http://localhost:8080) | Workflow orchestration dashboard |  `admin` / `KEYCLOAK_ADMIN_PASSWORD`|
   | **Keycloak Admin** | [http://localhost:18080/admin](http://localhost:18080/admin) | Identity & access management | `admin` / `KEYCLOAK_ADMIN_PASSWORD` |
   | **API Documentation** | [http://localhost:5001/api-docs](http://localhost:5001/api-docs) | Interactive API documentation | No authentication required |

   ### 🔐 Authentication Notes

   - **Default Username**: `admin` for both XiansAi Platform and Keycloak
   - **Password**: Use the value you set for `KEYCLOAK_ADMIN_PASSWORD` in your `.env` file

   ### 🖥️ Host Configuration (Required for some services)

   Some services require host file entries to work properly. Add these entries **only once**:

   ```bash
   # Check if entries already exist to avoid duplicates
   grep -q "keycloak" /etc/hosts || echo "127.0.0.1   keycloak" | sudo tee -a /etc/hosts
   grep -q "mongodb" /etc/hosts || echo "127.0.0.1   mongodb" | sudo tee -a /etc/hosts
   ```
    ### 🖥️ Windows Host File Setup

    On Windows, you need administrator privileges to edit the hosts file. Scripts cannot update it automatically.

    1. Open Notepad as Administrator:
      - Search for "Notepad" in the Start menu, right-click, and select "Run as administrator".
    2. Open the hosts file:
      - File > Open, then navigate to `C:\Windows\System32\drivers\etc\hosts` (set file type to "All Files").
    3. Add or update these lines:
      ```
      127.0.0.1   host.docker.internal
      ```
      > If `host.docker.internal` is set to another IP (e.g., `192.168.1.7`), change it to `127.0.0.1`.
    4. Save the file and close Notepad.

    **Note:** You must have administrator rights to save changes.

    **What these entries do:**
    - `host.docker.internal`: Ensures Docker containers can access services on your local machine. On Windows, this may default to another IP (e.g., `192.168.1.7`); update it to `127.0.0.1` if needed.

   ### 💾 Database Access

   **MongoDB Connection**: The connection string is available in `server/.env.local` under `MongoDB__ConnectionString`.

   **Direct Database Access**:

   ```bash
   # Using MongoDB Compass or similar tools
   # Connection string format: mongodb://mongodb:27017/xiansai
   # Replace 'mongodb' with 'localhost' if host entry not added
   # Find the connection string in generate `server/.env.local` file.
   ```

   ### ✅ Verify Services are Running

   ```bash
   # Check all service status
   docker compose ps

   # Test service endpoints
   curl -s http://localhost:3001 > /dev/null && echo "✅ XiansAi UI is running"
   curl -s http://localhost:8080 > /dev/null && echo "✅ Temporal UI is running"
   curl -s http://localhost:5001/api-docs > /dev/null && echo "✅ XiansAi Server is running"
   curl -s http://localhost:18080 > /dev/null && echo "✅ Keycloak is running"

   ```

## 📋 Configuration

### Script Options

**start-all.sh** supports the following options:

```bash
-v, --version VERSION    Docker image version (default: latest)
-e, --env ENV_POSTFIX    Environment postfix (default: local)
-d, --detached           Run in detached mode (default)
-h, --help               Show help message
```

**reset-all.sh** supports the following options:

```bash
-f, --force              Skip confirmation prompts
-h, --help               Show help message
```

**pull-latest.sh** supports:

```bash
-v, --version VERSION    Docker image version to pull (default: latest)
-h, --help               Show help message
```

**stop-all.sh** supports:

```bash
-h, --help               Show help message
```

### Examples

```bash
# Development setup (default)
./start-all.sh

# Production environment
./start-all.sh -v v2.1.0 -e production

# Pull latest images
./pull-latest.sh

# Pull specific version images
./pull-latest.sh -v v2.1.0

# Stop services (works for any running configuration)
./stop-all.sh

# Complete reset without confirmation prompts
./reset-all.sh -f
```

### View logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f xiansai-server
docker compose logs -f xiansai-ui
```

### Docker Releases

```bash
# Define the version
export VERSION=v1.3.7 # or 1.3.7-beta for pre-release

# Create and push a version tag
git tag -a v$VERSION -m "Release v$VERSION"
git push origin v$VERSION
```

## 🏗️ Platform Architecture

### Primary Platform Repositories

The XiansAi Platform consists of multiple repositories:

- **XiansAi.Server**
  - Docker Hub [99xio/xiansai-server](https://hub.docker.com/repository/docker/99xio/xiansai-server/general)
  - Repository: [XiansAi.Server](https://github.com/XiansAiPlatform/XiansAi.Server)
- **XiansAi.UI**
  - Docker Hub [99xio/xiansai-ui](https://hub.docker.com/repository/docker/99xio/xiansai-ui/general)
  - Repository: [XiansAi.UI](https://github.com/XiansAiPlatform/XiansAi.UI)
- **XiansAi.Lib**
  - NuGet [XiansAi.Lib](https://www.nuget.org/packages/XiansAi.Lib)
  - Repository: [XiansAi.Lib](https://github.com/XiansAiPlatform/XiansAi.Lib)
- **sdk-web-typescript**
  - npm [@99xio/xians-sdk-typescript](https://www.npmjs.com/package/@99xio/xians-sdk-typescript)
  - Repository: [sdk-web-typescript](https://github.com/XiansAiPlatform/sdk-web-typescript)
- **community-edition**
  - Release in this repository [XiansAi Platform Community Edition](https://github.com/XiansAiPlatform/community-edition/releases)

## 📚 Documentation

- **[Agent Development Guide](https://xiansaiplatform.github.io/XiansAi.PublicDocs/)** - Agent development guide
- **[Complete Setup Guide](docs/SETUP_GUIDE.md)** - Comprehensive setup guide for fresh users
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute to the project
- **[Release Guide](docs/RELEASE_GUIDE.md)** - Complete release process and documentation for maintainers
- **[XiansAi Website](https://xians.ai)** - XiansAi Website

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. See our [Contributing Guide](CONTRIBUTING.md) for detailed instructions.
