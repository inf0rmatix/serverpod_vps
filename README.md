# serverpod_vps

Before you get started with the CLI, please review our comprehensive
[Serverpod VPS Deployment Guide](./lib/assets/templates/serverpod_templates/github/workflows/deployment-docker.md).
This guide details everything you need to set up your Serverpod VPS deployment
using Docker and GitHub Actions. **serverpod_vps** is designed to help you
implement the guide quickly and efficiently by generating all the required
configuration and deployment files.

## Overview

**serverpod_vps** is a companion CLI tool that streamlines the creation of a
production-ready deployment configuration for Serverpod projects. It automates
file generation for Docker deployments and integrates seamlessly with GitHub
Actions to facilitate continuous deployment to your Virtual Private Server.

## Where to start

> 🚀 Follow the steps in the [Serverpod VPS Deployment Guide](./lib/assets/templates/serverpod_templates/github/workflows/deployment-docker.md).

## Key Features

- **Automated File Generation:** Instantly create deployment files like `docker-compose.production.yaml` and related scripts.
- **GitHub Actions Integration:** Pre-configured workflows to automate deployment using Docker.
- **SSL & DNS Support:** Simplified configuration for secure HTTPS connections via Traefik and Let's Encrypt.
- **Optimized for VPS Deployments:** Specially tailored for Serverpod projects, with support for ARM-based machines (e.g., Hetzner Cloud).

## Prerequisites

Before using **serverpod_vps**, ensure that you have:

- A Serverpod project set up.
- A VPS configured with Docker and Docker Compose.
- Properly configured SSH keys on your VPS.
- Required GitHub repository secrets (SSH keys, PAT, and Serverpod configuration) for deployment.
- Basic knowledge of terminal usage and SSH commands.

## Installation

Install the CLI tool globally using Dart:

```bash
dart pub global activate serverpod_vps
```

Make sure your Dart environment is correctly configured and that the Dart pub
global bin path is added to your system's PATH.

## Usage

1. **Navigate to Your Serverpod Project:**

   ```bash
   cd my_serverpod_project
   ```

2. **Run the CLI Tool:**

   ```bash
   serverpod_vps
   ```

3. **Follow the Interactive Prompts:**

   - Enter your email address for SSL certificate notifications.
   - Confirm or adjust deployment settings as needed.

The tool will generate all necessary deployment files and configuration
settings, helping you implement the steps outlined in the [Serverpod VPS
Deployment
Guide](./lib/assets/templates/serverpod_templates/github/workflows/deployment-docker.md).

## Additional Resources

For detailed instructions on setting up your VPS, configuring DNS and SSL
certificates, and deploying your Serverpod project, please refer to our
[Deployment Guide](./lib/assets/templates/serverpod_templates/github/workflows/deployment-docker.md).

## Troubleshooting

If you encounter any issues:

- **SSH Configuration:** Verify that your SSH keys are correctly set up on your VPS.
- **GitHub Secrets:** Ensure all required secrets are correctly added to your GitHub repository.
- **Docker Services:** Confirm that Docker and Docker Compose are installed and functioning properly.
- **Documentation:** Consult the full [Deployment Guide](./lib/assets/templates/serverpod_templates/github/workflows/deployment-docker.md) for in-depth troubleshooting tips.

## License

MIT License
