<!-- markdownlint-disable first-line-heading -->

## 1.0.6

- Use a project-specific Docker network name via the `{{DOCKER_NETWORK_NAME}}` placeholder in generated `docker-compose.production.yaml` instead of the hardcoded `serverpod-network`
- Sanitize project names so generated Docker network names only contain valid characters
- Inform when the Docker network name is sanitized or truncated to fit Docker limits
- **Note:** Existing deployments must update `docker-compose.production.yaml` to use the new network name or re-run `serverpod_vps` to regenerate the file

## 1.0.5

- Bump generated GitHub Actions to Node 24-compatible versions (`checkout@v6`, `login-action@v4`, `metadata-action@v6`, `setup-buildx-action@v4`, `build-push-action@v7`)
- Build Docker images for `linux/arm64` only (64-bit ARM VPS, e.g. Hetzner Cloud)

## 1.0.4

- Pass IdP/JWT password keys via `SERVERPOD_PASSWORD_*` in generated `docker-compose.production.yaml` and GitHub Actions deploy env (for `serverpod_auth_idp_server` + `JwtConfigFromPasswords()`)
- Document corresponding repository secrets in the deployment guide

## 1.0.3

- Updated documentation

## 1.0.2

- Updated Traefik from v3.0 to v3.6.2 for Docker API compatibility

## 1.0.1

- Fixed postgres image version to 17

## 1.0.0

- Updated to use Traefik v3
- Fixed setup instructions

## 0.0.8

- Fixed a bug where the project name was not being detected when root directory name was not the same as the project name
- Added tests

## 0.0.7

- Added example readme
- Added documentation

## 0.0.6

- dart format

## 0.0.5

- Improved README
- Improved Guide

## 0.0.4

- Added `docker` topic to pub.dev
- Fixed copying assets

## 0.0.3

- Moved assets to lib

## 0.0.2

- Fixed pubspec.yaml `files` section

## 0.0.1

- Initial release
