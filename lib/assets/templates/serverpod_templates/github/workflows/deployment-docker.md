# Serverpod Deployment to a VPS using Docker

> 💡 Deploying Serverpod to a Virtual Private Server (VPS) using Docker is a
> cost-effective and scalable solution for startups and small- to medium-scale
> projects.

This guide walks you through deploying a server built using the Serverpod
framework to a Virtual Private Server (VPS) with Docker.

Serverpod is a Flutter/Dart backend framework offering database integration and
seamless client–server communication. VPS deployment provides a cost-effective
solution for small to medium projects.

The setup allows vertical scaling through VM upgrades and can be extended to
horizontal scaling with load balancers. This guide helps you create a
production-ready Docker Compose deployment.

To reduce the workload on the machine, we do not use Redis in this deployment.
(Redis becomes necessary when you want to scale your application horizontally.)

> 💡 In many cases, scaling vertically is sufficient and saves you the hassle of
> setting up a load balancer and additional infrastructure. Always start with
> vertical scaling and only scale horizontally if you need to.

## Prerequisites

- This guide assumes you have basic knowledge of Serverpod and command-line usage.
- This guide contains terminal commands that are specific to Unix-based systems (macOS & Linux).
- The `docker-compose.production.yaml` file is configured to run on ARM machines.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Table of Contents](#table-of-contents)
- [Preparing the server](#preparing-the-server)
  - [Registering at Hetzner Cloud](#registering-at-hetzner-cloud)
  - [Setting up an SSH key to connect to the server](#setting-up-an-ssh-key-to-connect-to-the-server)
  - [Creating a new server](#creating-a-new-server)
  - [Setting up the server](#setting-up-the-server)
    - [Step 1: Create the new user](#step-1-create-the-new-user)
    - [Step 2: Grant Docker permissions](#step-2-grant-docker-permissions)
    - [Step 3: Enable SSH access](#step-3-enable-ssh-access)
    - [Step 4: Set up SSH key-based authentication](#step-4-set-up-ssh-key-based-authentication)
  - [Firewall configuration](#firewall-configuration)
- [Preparing the domain](#preparing-the-domain)
- [Preparing the repository](#preparing-the-repository)
  - [Getting a GitHub Personal Access Token](#getting-a-github-personal-access-token)
  - [Adding the secrets to the repository](#adding-the-secrets-to-the-repository)
- [Creating the deployment files](#creating-the-deployment-files)
- [Configuring SSL-certificates](#configuring-ssl-certificates)
- [Configuring the GitHub-Action](#configuring-the-github-action)
- [Running the GitHub-Action](#running-the-github-action)
- [Using the Serverpod Insights app](#using-the-serverpod-insights-app)
- [Connecting your Flutter client](#connecting-your-flutter-client)
- [Connecting to the Database using DBeaver](#connecting-to-the-database-using-dbeaver)

## Preparing the server

This guide uses Hetzner Cloud. You can use any server provider, but Hetzner is a
good and cost-effective option. If you want to use another architecture or
provider, check the Docker Compose file and the deployment script for any
necessary changes. Currently, the deployment is meant to run on ARM machines.

### Registering at Hetzner Cloud

Register an account at Hetzner Cloud and create a new project.  
[Use this referral link to get €20 credits for free at Hetzner Cloud](https://hetzner.cloud/?ref=BFdFFipLgfDs)

Next, go to the [Cloud Console](https://console.hetzner.cloud/) and create a project.

### Setting up an SSH key to connect to the server

In order to configure your server, you need to access it through SSH. Create an
SSH keypair if you don't have one yet. If you are not sure whether you already
have one, you can check by running:

```bash
cat ~/.ssh/id_rsa.pub
```

To create a new keypair, run the following command. Leave all options at their
default values by pressing enter.

```bash
ssh-keygen -t rsa -b 4096
```

When asked for a password, don't enter anything—just press enter. This will
create a keypair in `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`.

Copy the public key to your clipboard:

```bash
cat ~/.ssh/id_rsa.pub
```

Select the output and copy it.

In your Hetzner project, follow these steps:

1. In the left-hand menu, click on **Security** > **SSH keys** > **Add SSH key**.
2. Paste the public key you generated earlier.

### Creating a new server

Continuing in your Hetzner project, create a new server:

1. In the left-hand menu, go to **Server** and click **Create server**.
2. In the **Image** section, click on **Apps** and select **Docker CE**.
3. **Type/Architecture:** Select **vCPU** and **Arm64 (Ampere)**. The smallest tier is sufficient for most projects—you can always upgrade the specs later.
4. Ensure that the public IPv4 address is enabled.
5. In the SSH-Keys section, make sure your SSH key is selected.
6. Name your server and create it.

### Setting up the server

Once the server is created, you can connect to it using SSH. Find the server IP
in the Hetzner Cloud Console and connect using the following command:

```bash
ssh root@<your-server-ip>
```

When prompted with "Are you sure you want to continue connecting? [...]" type "yes" and press enter.

> If you are asked for a password, it means the SSH key was not added correctly.
> Delete the corresponding entry from `~/.ssh/known_hosts` and delete the
> server. Then create a new server and ensure the SSH key is added correctly.

For security reasons, we will create a new user to manage the deployment. This user will not have root privileges.

#### Step 1: Create the new user

```bash
sudo adduser github-actions
```

Replace `github-actions` with your desired username. This command will prompt
you to set a password and enter user information.

#### Step 2: Grant Docker permissions

Add the user to the `docker` group so they can run Docker commands:

```bash
sudo usermod -aG docker github-actions
```

#### Step 3: Enable SSH access

SSH access is available by default for any user on the server. However, to ensure proper access, check the `sshd_config` file:

```bash
sudo nano /etc/ssh/sshd_config
```

Find or add the `AllowUsers` directive. This directive specifies which users are
allowed to SSH into the server. If it doesn't exist, add it at the end of the
file. If there are multiple users, separate them with spaces:

```text
AllowUsers root github-actions
```

To save and exit the file, press `Ctrl + X`, then `Y`, and finally `Enter`. Restart the SSH service to apply the changes:

```bash
sudo systemctl restart ssh
```

#### Step 4: Set up SSH key-based authentication

1. Log in as the new user:

   ```bash
   su - github-actions
   ```

2. Create an SSH keypair:

   ```bash
   ssh-keygen -t rsa -b 4096
   ```

   Leave the options at their default values by pressing enter.

3. Add the public SSH key to the `authorized_keys` file:

   ```bash
   cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
   ```

4. Copy the private key to your clipboard—including the lines `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----`. Save this key in a secure location, as you will need it later. To display the private key, run:

   ```bash
   cat ~/.ssh/id_rsa
   ```

5. Logout from the github-actions user:

   ```bash
   exit
   ```

6. Restart the SSH service to apply changes:

   ```bash
   sudo systemctl restart ssh
   ```

### Firewall configuration

In the Hetzner Web Interface, enter your server configuration and click on **Firewalls**, then click **Create Firewall**.

By default, there will be two inbound rules: one for SSH (port 22) and one for ICMP. We will add two more for HTTP and HTTPS.

1. Click on **Add Rule**, name it HTTP, set the port to 80, and choose TCP as the protocol.
2. Click on **Add Rule**, name it HTTPS, set the port to 443, and choose TCP as the protocol.

If you use custom Traefik host ports for a second stack (for example `8088` and `8443`), add matching firewall rules for those ports as well.

1. In the "apply to" section, make sure your server is selected.
2. Click **Create Firewall**.

## Preparing the domain

To access your server, you need to have a domain. You can purchase a domain from
any provider (e.g., [Namecheap](https://www.namecheap.com/) or
[GoDaddy](https://www.godaddy.com/)).

Once you have a domain, set up the DNS records to point to your server. Create
the following DNS records, replacing `Your server IP` with the IP address of
your server:

| Type | Name     | Value          |
| ---- | -------- | -------------- |
| A    | api      | Your server IP |
| A    | web      | Your server IP |
| A    | insights | Your server IP |

The full domains will be `api.your-domain.com`, `web.your-domain.com`, and `insights.your-domain.com`.

## Preparing the repository

### Getting a GitHub Personal Access Token

1. Create a new Personal Access Token (PAT) on GitHub:
   - Click on your profile picture in the top-right corner.
   - Navigate to **Settings** > **Developer settings** > **Personal access tokens** > **Tokens (classic)**.
   - Click on **Generate new token**.

2. Fill in the required fields:
   - In the **Note** field, set a name for the token, e.g., "Serverpod Deployment".
   - Set the expiration to **No expiration**.

3. Select the necessary scopes:
   - **repo**: Required to read repositories, especially private ones.
   - **write:packages**: Required to push Docker images to the GitHub Package Registry.

4. Generate and save the token:
   - Scroll to the bottom and click **Generate token**.
   - Copy the token and save it in a secure place.

### Adding the secrets to the repository

Go to your Serverpod project repository, then navigate to **Settings** > **Secrets and variables** > **Actions** and create the following secrets:

| Secret Name     | Value                                                           |
| --------------- | --------------------------------------------------------------- |
| PAT_USER_GITHUB | Your GitHub username                                            |
| PAT_GITHUB      | Your GitHub PAT token                                           |
| SSH_HOST        | The IP address of your server                                   |
| SSH_USER        | The username you created on the server (e.g., "github-actions") |
| SSH_PRIVATE_KEY | The private key you generated on the server                     |

The following secrets configure Serverpod and the database:

| Secret Name                           | Value                                                                                                       |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| SERVERPOD_DATABASE_NAME               | The name of the database (e.g., "serverpod")                                                                |
| SERVERPOD_DATABASE_USER               | The database user (e.g., "serverpod")                                                                       |
| SERVERPOD_DATABASE_PASSWORD           | The database password                                                                                       |
| SERVERPOD_API_SERVER_PUBLIC_HOST      | The domain for the API server (e.g., api.my-domain.com)                                                     |
| SERVERPOD_WEB_SERVER_PUBLIC_HOST      | The domain for the Web server (e.g., web.my-domain.com)                                                     |
| SERVERPOD_INSIGHTS_SERVER_PUBLIC_HOST | The domain for the Insights server (e.g., insights.my-domain.com)                                           |
| SERVERPOD_SERVICE_SECRET              | The same value as in your local `passwords.yaml` file, required to connect using the Serverpod Insights app |
| SERVERPOD_PASSWORD_EMAIL_SECRET_HASH_PEPPER     | Same value as the `emailSecretHashPepper` key in your local `passwords.yaml` (production) — required when using `serverpod_auth_idp_server` with `JwtConfigFromPasswords()` |
| SERVERPOD_PASSWORD_JWT_HMAC_SHA512_PRIVATE_KEY  | Same value as the `jwtHmacSha512PrivateKey` key in your local `passwords.yaml` (production) — required when using IdP JWT from passwords |
| SERVERPOD_PASSWORD_JWT_REFRESH_TOKEN_HASH_PEPPER | Same value as the `jwtRefreshTokenHashPepper` key in your local `passwords.yaml` (production) — required when using IdP JWT from passwords |
| CF_DNS_API_TOKEN                      | Cloudflare API token for Traefik ACME DNS challenge — **only** when using a non-standard HTTPS host port (see [Let's Encrypt with a custom HTTPS port](#lets-encrypt-with-a-custom-https-port)) |

The production Docker image does not ship `passwords.yaml`. Serverpod reads secret values from environment variables named `SERVERPOD_PASSWORD_<key>`, where `<key>` matches the camelCase key from `passwords.yaml` (for example, `SERVERPOD_PASSWORD_jwtRefreshTokenHashPepper`). The generated workflow and `docker-compose.production.yaml` pass the three IdP/JWT-related keys above from GitHub Actions into the container.

If you use `JwtConfigFromPasswords()` or extend IdP configuration with additional password keys, add each key the same way: declare it under the `serverpod` service `environment` in `docker-compose.production.yaml`, map a repository secret in `.github/workflows/deployment-docker.yml`, and document the secret here. Projects without `serverpod_auth_idp_server` / `JwtConfigFromPasswords()` do not need the three `SERVERPOD_PASSWORD_*` repository secrets unless your app references those password keys at runtime.

## Creating the deployment files

The CLI will generate all necessary deployment files for your project.

1. Install the Serverpod VPS CLI:

   ```bash
   dart pub global activate serverpod_vps
   ```

2. Navigate to your Serverpod project directory:

   ```bash
   cd my_serverpod_project
   ```

3. Run the CLI to generate deployment files:

   ```bash
   serverpod_vps
   ```

4. When prompted, enter your email address for SSL certificate notifications and the host ports for Traefik (HTTP/HTTPS) and Postgres. Use the defaults (`80`, `443`, `5432`) for the first stack on a VPS. Choose different ports for additional stacks on the same host.

## Running multiple Serverpod stacks on one VPS

Generated deployment files are isolated per project so multiple Serverpod apps can run on the same VPS:

- **Docker network:** Each project gets its own network name (for example `my_app-network`).
- **Traefik isolation:** Traefik only discovers containers labeled with a matching `serverpod_vps.instance` value (for example `my_app-vps`).
- **Router names:** Traefik routers and services are prefixed with the project name (for example `my_app-api`, `my_app-web`).
- **Host ports:** Each stack needs unique host ports for HTTP, HTTPS, and the local Postgres bind.

When generating files for a second stack on the same VPS, choose unused host ports during the CLI prompts (for example HTTP `8080`, HTTPS `8443`, Postgres `55432`).

If you choose a non-standard HTTPS host port, `serverpod_vps` prints a warning in the terminal. Follow the steps in [Let's Encrypt with a custom HTTPS port](#lets-encrypt-with-a-custom-https-port) so certificate issuance still works.

After generation, verify the `ports` section in `docker-compose.production.yaml` reflects your chosen host bindings.

## Configuring SSL-certificates

All external connections are secured by Traefik through HTTPS. Traefik uses
[Let's Encrypt](https://letsencrypt.org/) to automatically generate SSL
certificates for your domains.

The generated `docker-compose.production.yaml` uses the **TLS-ALPN challenge**
(`tlschallenge`). That works when Traefik is bound to host port **443** (the
default from the CLI prompts).

If you need to change the email address that Let's Encrypt uses for certificate
notifications, edit the email address in the `docker-compose.production.yaml`
file. Open the file and modify the value of the parameter
`certificatesresolvers.myresolver.acme.email`.

## Let's Encrypt with a custom HTTPS port

Use this when port `443` is already taken by another stack on the same VPS, or
when you deliberately map Traefik HTTPS to another host port (for example
`8443:443`).

```mermaid
flowchart LR
  LE["Let's Encrypt"] -->|TLS challenge| P443["Public port 443"]
  LE -->|DNS challenge| CF["Cloudflare DNS TXT record"]
  P443 --> T443["Traefik on host 443"]
  CF --> T8443["Traefik on host 8443"]
```

**TLS challenge (default):** Let's Encrypt connects to your domain on public port
`443`. It does **not** follow a Docker mapping like `8443:443`. If Traefik only
listens on host port `8443`, the default generated config will not obtain
certificates.

**DNS challenge (custom HTTPS port):** Let's Encrypt verifies domain ownership
via a DNS TXT record. Traefik can run on any host HTTPS port. This requires your
domains to be managed in **Cloudflare**.

### 1. Switch Traefik to DNS challenge in `docker-compose.production.yaml`

In the `traefik` service `command` section, replace the TLS challenge lines:

```yaml
# Remove:
- "--certificatesresolvers.myresolver.acme.tlschallenge=true"

# Add:
- "--certificatesresolvers.myresolver.acme.dnschallenge=true"
- "--certificatesresolvers.myresolver.acme.dnschallenge.provider=cloudflare"
```

Add the Cloudflare token to the `traefik` service `environment`:

```yaml
environment:
  - CF_DNS_API_TOKEN
```

Example host port mapping for a second stack:

```yaml
ports:
  - "8088:80"
  - "8443:443"
```

### 2. Add the GitHub secret and deploy env var

| Secret | Purpose |
| ------ | ------- |
| `CF_DNS_API_TOKEN` | Cloudflare API token with DNS edit permission for your zone |

In `.github/workflows/deployment-docker.yml`, pass the token into the deploy step
`env` (alongside your other variables):

```yaml
CF_DNS_API_TOKEN: ${{ secrets.CF_DNS_API_TOKEN }}
```

### 3. Align Serverpod public ports with your host binding

The generated workflow sets `SERVERPOD_*_PUBLIC_PORT` to `443`. Change these to
your HTTPS host port (for example `8443`):

```yaml
SERVERPOD_API_SERVER_PUBLIC_PORT: 8443
SERVERPOD_INSIGHTS_SERVER_PUBLIC_PORT: 8443
SERVERPOD_WEB_SERVER_PUBLIC_PORT: 8443
```

In `config/production.yaml`, set `publicPort` on all three servers to the same
value:

```yaml
apiServer:
  publicPort: 8443
insightsServer:
  publicPort: 8443
webServer:
  publicPort: 8443
```

### 4. Update clients and OAuth redirect URIs

When `publicPort` is not `443`, URLs must include the port explicitly:

- Flutter / client: `https://api.my-domain.com:8443/`
- OAuth callbacks (example): `https://web.my-domain.com:8443/auth/callback`

### 5. Open the custom ports in your firewall

Add inbound TCP rules for the HTTP and HTTPS host ports you chose (for example
`8088` and `8443`), in addition to or instead of `80`/`443` depending on your
setup.

## Configuring the GitHub-Action

From the root of your repository, open the `.github/workflows/deployment-docker.yml` file and adjust the following settings:

- Update the `GHCR_ORG` variable by replacing `<ORGANIZATION>` with your GitHub username or organization name. In case your repository belongs to an organization, you must use the organization name, username will not work in this case.
- At the top of the file, you can change the branches that automatically trigger the deployment. By default, it is set to `main`. You can also trigger the action manually on a different branch.

## Running the GitHub-Action

Push your changes to the repository on the configured branch.

To manually trigger the action, go to the **Actions** tab in your repository,
click on the **Deploy to Docker** workflow, then click **Run workflow** and
select the branch you want to deploy.

## Using the Serverpod Insights app

To enable the [Serverpod Insights app](https://docs.serverpod.dev/tools/insights),
adjust the insights server host in `production.yaml` to the domain you set up in
your DNS records. Ensure that the service secret specified in the repository
secrets matches the one in your local `passwords.yaml` file for production.

## Connecting your Flutter client

To connect with your generated client, use the domain you set up in the DNS.

- **Standard HTTPS (port 443):** `https://api.my-domain.com`
- **Custom HTTPS host port:** include the port in the URL, for example
  `https://api.my-domain.com:8443/` — and match `publicPort` in
  `production.yaml` and `SERVERPOD_*_PUBLIC_PORT` in the deploy workflow (see
  [Let's Encrypt with a custom HTTPS port](#lets-encrypt-with-a-custom-https-port)).

## Connecting to the Database using DBeaver

To manage your database, you can use a tool like [DBeaver](https://dbeaver.io/).
To connect to the database, set up an SSH tunnel to the server using the
following example:

1. Open DBeaver and click the **New Database Connection** button (usually in the top-left corner).
2. Select **PostgreSQL** and click **Next**.
3. Click the **SSH** tab.
4. Check **Use SSH tunnel**.
5. Set the following values:
   - **Host/IP:** Your server IP
   - **Port:** 22
   - **Username:** root
   - **Authentication method:** Public key
   - **Private key:** The private key on your machine you [generated earlier](#setting-up-an-ssh-key-to-connect-to-the-server)
6. Click **Test tunnel** to verify the connection.
7. Return to the **Main** tab.
8. Set the following values:
   - **Host:** localhost
   - **Port:** The Postgres host port from your `docker-compose.production.yaml` (default `5432`, or the value you chose when running `serverpod_vps`)
   - **Database:** The database name you set in the [repository secrets](#adding-the-secrets-to-the-repository)
   - **User name:** The database user you set in the [repository secrets](#adding-the-secrets-to-the-repository)
   - **Password:** The database password you set in the [repository secrets](#adding-the-secrets-to-the-repository)
9. Test the connection and save it.
