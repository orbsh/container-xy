# XY Image Repository & CI System

The `xy` repository is a centralized container image registry and build system. It replaces traditional Docker-based workflows with a declarative, Nushell-driven approach using the `bx` framework.

## Core Components

| Component | Description |
|-----------|-------------|
| **[bx](bx/README.md)** | Nushell-based `buildah` wrapper. Replaces Dockerfiles with programmable Nushell scripts. Provides `build`, `hub install`, `with-mount`, and other primitives. |
| **vessel** | Airgap distribution tool. Bundles packages defined in `hub.yaml` into compressed `.tar.zst` archives for offline environments. Built on top of `bx`. |
| **hub.yaml** | Central package manifest. Defines download URLs, versions, and bundle configurations for all third-party dependencies. |
| **images/** | Declarative image definitions (`.nu` scripts) organized by category: `core`, `service`, `database`, `tools`, `ext`. |

## Architecture

### The `bx` Framework
Instead of writing `Dockerfile`s, `xy` uses `.nu` scripts (e.g., `images/service/ferron.nu`) that describe the build process imperatively.
```nushell
use ../../bx *

export def main [context: record = {}] {
    {
        from: 'ghcr.io/fj0r/xy:deb'
        image: 'ferron'
        tag: 'deb'
    }
    | merge $context
    | build {|ctx|
        conf expose [8080]
        hub install [ferron] -c $ctx.cache?
        with-mount {
            # Configuration files embedded directly via Nushell raw strings
            r#':8080 { root "/srv" }'#
            | save etc/ferron.kdl
        }
        conf cmd ['srv']
    }
}
```
> 📘 For detailed `bx` API, environment variables, and usage, see [bx/README.md](bx/README.md).

### Vessel (Airgap Bundling)
The `vessel` image processes `hub.yaml` to download and bundle all required packages into a single distributable archive. This allows airgapped servers to install complex stacks (like Python, Rust, or Node.js ecosystems) without internet access.
```nushell
hub install $pkg -c $ctx.cache? -t /opt/vessel --bundle --with-python
```

## Build Workflow

1.  **Build Images**: Use the `x.nu` entrypoint to trigger builds.
    ```nushell
    ./x.nu build --with-steel
    ```
2.  **Airgap Export**: Build the `vessel` image to generate offline bundles.
3.  **CI/CD**: Changes to `x.toml` or `images/` trigger automated builds and pushes via centralized CI pipelines.

## Configuration

- **`x.toml`**: Defines image manifests, repository targets, and CI mapping.
- **`hub.yaml`**: The source of truth for all third-party package versions and download links.
