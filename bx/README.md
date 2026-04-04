# bx Framework

The `bx` framework is a Nushell-based container image building framework that wraps `buildah` functionality. It provides a flexible way to build container images using Nushell scripts with full programming language capabilities.

## Build Context Fields

The `build` function accepts a record as context (passed via pipeline `$in`). Below are all the context fields used by the build process.

### Required Fields

| Field | Type | Description | Usage Location |
|-------|------|-------------|----------------|
| `from` | string | Base image name used for `buildah from` | `build.nu#L18` |
| `image` | string | Image name (without tag) used to construct the full image reference | `build.nu#L55` |

### Optional Fields

| Field | Type | Default | Description | Usage Location |
|-------|------|---------|-------------|----------------|
| `tag` | string | `'latest'` | Image tag | `build.nu#L52` |
| `author` | string | - | Image author, used for configuration and push authentication (paired with `password` for `--creds`) | `build.nu#L21`, `build.nu#L59` |
| `password` | string | - | Password used with `author` for `--creds` authentication when pushing | `build.nu#L59` |
| `skip_push` | bool | `false` | Whether to skip image push | `build.nu#L59` |

### Context Usage Example

```nu
{
    from: 'ghcr.io/fj0r/xy:py'        # Required: base image
    image: 'test-skill'               # Required: image name
    tag: 'latest'                     # Optional: tag, defaults to latest
    author: 'master'                  # Optional: author
    password: 'master'                # Optional: password (required for push)
    skip_push: true                   # Optional: skip push
}
| build {|ctx|
    # Build logic
    conf cmd ["python3", "libs/cli.py", "serve"]
    conf workdir /app
}
```

### Important Notes

1. **Minimum Required Fields**: Only `from` and `image` are strictly required to complete a basic build.

2. **Push-Related Fields**: If you need to push the image (`skip_push` is false or not set), then `author` and `password` are effectively required for authentication.

3. **Default Behaviors**:
   - `tag`: defaults to `latest` if not specified
   - `skip_push`: defaults to `false` (will attempt to push)

4. **Project-Specific Fields**: Additional fields like `ci` may be used by specific projects built on top of bx, but are not part of the core bx framework.

5. **Environment Variables**: During build, the following environment variables are available:
   - `BX_WORKDIR`: Working directory (defaults to `$env.PWD`)
   - `BX_DATADIR`: Data directory
   - `BUILDAH_WORKING_CONTAINER`: Working container name
   - `BUILDAH_WORKING_MOUNTPOINT`: Mount point path
   - `OS_RELEASE_ID`: OS identifier from the container
   - `SSH_WORKING_HOST`: Working host for SSH (reserved for future use)

6. **hub.install Command**: The `hub install` command supports the following options:
   - `--target(-t)`: Installation target directory (default: `/usr/local`)
   - `--cache(-c)`: Cache directory for downloaded packages
   - `--bundle`: Bundle mode - creates compressed archives (`.tar.zst`) instead of installing, useful for providing download/installation services (e.g., CGI-based installation services as demonstrated in `images/service/ferron/vessel.nu`)
   - `--arch`: Target architecture (default: system architecture)
   - `--with-python`: Include Python version detection
   - `--option(-o)`: Custom options closure for package configuration

7. **Build Function Parameters**: The `build` function supports the following optional parameters:
   - `--expose`: Debug mode - injects environment variables and returns without committing
   - `--no-commit`: Skip the commit step
   - `--squash`: Use squash mode when committing
   - `--workdir(-w)`: Specify working directory
   - `--datadir(-d)`: Specify data directory

## Module Exports

The `bx` module exports the following submodules:

- `build.nu` - Core build functionality
- `b.nu` - Helper commands (`copy`, `run`, `exec`, `commit`, `with-mount`) and `conf` submodule (`env`, `expose`, `volume`, `workdir`, `entrypoint`, `cmd`, `user`)
- `trace.nu` - Logging and tracing utilities
- `pkg.nu` - Package management
- `rust.nu` - Rust toolchain setup
- `nushell.nu` - Nushell installation and configuration
- `setup.nu` - General setup utilities
- `hub.nu` - Package installation and management (`get-version`, `install`, `sync`, `run-script`, `gen-script`)
- `transformer.nu` - Data transformation utilities
- `extract.nu` - Extraction utilities
- `ghcr.nu` - GitHub Container Registry operations
- `reverse.nu` - Reverse proxy utilities
- `upterm.nu` - Uterm terminal utilities
- `utils.nu` - Utility functions (`relative-path`, `into-tree`)