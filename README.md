# dokku-foundationdb

A Dokku service plugin for running a single-node [FoundationDB](https://www.foundationdb.org/) service in the official container image.

> [!WARNING]
> This plugin currently provisions one `fdbserver` process with `single` redundancy. It is useful for development and small, non-critical deployments, but it is not a fault-tolerant FoundationDB topology. FoundationDB has no password authentication in this configuration; keep the service on trusted Docker networks.

## Requirements

- A current Dokku installation with the `docker-options` plugin enabled
- Docker
- An application image containing FoundationDB client libraries compatible with the server version

The default image is `foundationdb/foundationdb:7.3.77`.

## Installation

Install the plugin from GitHub:

```shell
sudo dokku plugin:install https://github.com/danielwaterworth/dokku-foundationdb.git foundationdb
```

For local development, commit the checkout to a Git repository and install it through a local `file://` URL.

## Quick start

```shell
dokku apps:create myapp
dokku foundationdb:create mydb
dokku foundationdb:link mydb myapp
```

The first link sets this application config variable:

```text
FDB_CLUSTER_FILE_CONTENTS=dokku_mydb:RANDOM_ID@CONTAINER_IP:4500
```

There is deliberately no app-side bind mount. Your application entrypoint should write the value to a writable cluster file before starting the application, for example:

```shell
install -d "${XDG_RUNTIME_DIR:-/tmp}/foundationdb"
printf '%s\n' "$FDB_CLUSTER_FILE_CONTENTS" >"${XDG_RUNTIME_DIR:-/tmp}/foundationdb/fdb.cluster"
export FDB_CLUSTER_FILE="${XDG_RUNTIME_DIR:-/tmp}/foundationdb/fdb.cluster"
exec your-application
```

FoundationDB clients may update their cluster file, so the generated file and its parent directory must remain writable for the lifetime of the process.

The service container uses a plugin-owned entrypoint instead of the image's default startup script. This preserves the unique cluster identity stored in `fdb.cluster` and passes `--config-options` through to `fdbserver`.

The plugin also adds a Docker link so the app container can reach the service's private IP. Additional FoundationDB links receive generated variables such as `DOKKU_FOUNDATIONDB_BLUE_CLUSTER_FILE_CONTENTS`. Select an explicit variable name with `--alias`:

```shell
dokku foundationdb:link mydb myapp --alias PRIMARY_FDB
# sets PRIMARY_FDB_CLUSTER_FILE_CONTENTS
```

## Commands

```text
foundationdb:app-links <app>
foundationdb:connect <service>
foundationdb:create <service> [options]
foundationdb:destroy <service> [-f|--force]
foundationdb:enter <service> [command...]
foundationdb:exists <service>
foundationdb:info <service> [flag]
foundationdb:link <service> <app> [--alias NAME] [--no-restart]
foundationdb:linked <service> <app>
foundationdb:links <service>
foundationdb:list
foundationdb:logs <service> [-t|--tail] [lines]
foundationdb:restart <service>
foundationdb:set <service> <key> [value]
foundationdb:start <service>
foundationdb:stop <service>
foundationdb:unlink <service> <app> [--no-restart]
```

Create options include:

```text
--storage-engine ssd|memory
--image IMAGE
--image-version VERSION
--memory MEGABYTES
--custom-env 'KEY=value;OTHER=value'
--config-options '--knob_name=value'
--initial-network NETWORK
--post-create-network NETWORK[,NETWORK...]
--post-start-network NETWORK[,NETWORK...]
```

The default `ssd` engine persists data below Dokku's service data root. The `memory` engine loses its contents when the process stops.

Useful info queries:

```shell
dokku foundationdb:info mydb --connection-string
dokku foundationdb:info mydb --status
dokku foundationdb:info mydb --version
dokku foundationdb:info mydb --data-dir
```

Open the FoundationDB CLI with:

```shell
dokku foundationdb:connect mydb
```

## Networking and lifecycle

FoundationDB cluster connection strings require numeric IP addresses, not DNS names. The plugin therefore keeps a stopped service container instead of deleting and recreating it, preserving its Docker network identity across normal `stop`, `start`, and `restart` operations.

Do not manually remove or rename the service container. If it is missing, `start` recreates it, rewrites the service connection string, and updates linked app config without restarting those apps. Restart linked apps after such a recovery.

Public `expose` is intentionally not implemented. A simple port-forwarding sidecar is insufficient because FoundationDB advertises the coordinator's private address to clients. Use an explicitly designed private network or a proper multi-node FoundationDB deployment for access beyond the Dokku host.

## Current scope

- One FoundationDB process and `single` redundancy per service
- `ssd` and `memory` storage engines
- Private Docker networking and connection-string-based app links
- No TLS setup, public exposure, backup/restore, multi-node clustering, or rolling upgrades yet

## Attribution

This project is based on the official [`dokku-postgres`](https://github.com/dokku/dokku-postgres) plugin, originally written by Jose Diaz-Gonzalez.

## Development

```shell
make test
make test-docker
```

The default test target validates every shell entrypoint and runs focused helper tests. If `shellcheck` is installed, it is run as well. The Docker test creates a temporary single-node cluster with the pinned image and verifies that it becomes ready without changing its cluster identity.
