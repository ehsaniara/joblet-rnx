# rnx

`rnx` is the command-line client for [Joblet](https://github.com/ehsaniara/joblet) - 
run, inspect, and manage isolated jobs, volumes, networks, and runtimes on a
Joblet node over mTLS gRPC.

This is the standalone home of the CLI. Its only coupling to the Joblet server
is the published gRPC contract, [`joblet-proto`](https://github.com/ehsaniara/joblet-proto);
the two share no source or config file.

## Install

Prebuilt binaries for linux/amd64, linux/arm64, darwin/amd64, darwin/arm64,
and windows/amd64 are published on the
[releases page](https://github.com/ehsaniara/joblet-rnx/releases/latest).

Homebrew (macOS and Linux):

```bash
brew tap ehsaniara/rnx https://github.com/ehsaniara/joblet-rnx
brew install rnx
```

From source:

```bash
make build            # -> bin/rnx
make install          # -> /usr/local/bin/rnx (sudo)
```

Or with the Go toolchain:

```bash
go install github.com/ehsaniara/joblet-rnx/cmd/rnx@latest
```

## Compatibility

rnx is versioned independently of the Joblet server. The two share no code;
their only contract is the gRPC API,
[`joblet-proto`](https://github.com/ehsaniara/joblet-proto), so compatibility
is defined by the proto contract both sides speak, not by matching version
numbers. Any rnx release works with any Joblet release on the same contract.

| rnx  | wire contract   | works with Joblet          |
|------|-----------------|----------------------------|
| v1.x | joblet-proto v2 | v5.0.2+ (any proto v2 server) |

Some commands need a server new enough to implement the RPC they call; see the
[joblet-proto compatibility feature timeline](https://github.com/ehsaniara/joblet-proto/blob/main/COMPATIBILITY.md)
for per-feature floors.

`rnx --version` prints both the client version and the server version of the
default node.

## Configure

rnx reads `rnx-config.yml` - the set of Joblet nodes and their embedded mTLS
certificates. The Joblet installer generates a populated file on the server;
copy it to `~/.rnx/rnx-config.yml` on the client. See
[`config/rnx-config.yml.template`](config/rnx-config.yml.template) for the shape.

Resolution order: `$RNX_CONFIG`, `./rnx-config.yml`, `./config/rnx-config.yml`,
`~/.rnx/rnx-config.yml`, `/etc/joblet/rnx-config.yml`,
`/opt/joblet/config/rnx-config.yml`. Override per-invocation with `--config` and
select a node with `--node`.

## Usage

```bash
rnx job run --gpu=1 --runtime=python-3.11-ml python train.py
rnx job list
rnx job log <id>
rnx job status <id>
rnx runtime list
rnx volume list
rnx network list
rnx --version
```

Run `rnx --help` for the full command set.

## Develop

```bash
make test        # unit tests
make vet
make smoke       # quick smoke test against a live node (uses ~/.rnx or RNX_CONFIG)
make e2e         # full e2e suite - expects joblet already running on this machine
make pre-pr      # vet + tests + cross-builds + e2e; run before every PR
```
