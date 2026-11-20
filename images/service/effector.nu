use ../../bx *

# Effector node image (effector ADR-0003 §10): the node IS the container's root process,
# so this image ships the binary, the config the node loads, the ToolRunner scripts, and
# the toolchain the delivered scripts run in.
#
# The node shells out to three external programs (`crates/runtime/src/resource.rs`):
#   git     — the `git` resource arm (ensure / sync)
#   curl    — the `object` arm's signed request (`--aws-sigv4 aws:amz:<region>:s3`)
#   rustic  — the `archive` arm
# There is no S3 client here on purpose: the node moves objects itself over curl's sigv4,
# and a delivered script names resources through `ctx.resource` instead of talking to S3.
#
# Launcher facts this image assumes (`effector/deploy/node-container.nu`):
#   docker run --rm --init -i <image> effector --control-plane <ws://…> --token-stdin
# so there is NO entrypoint to fight with — argv[1] absent means the node reads
# `./effector.json` from its working directory, which is why the default config lives at
# /work/effector.json. `node_alias` has no CLI override: a launcher that serves more than
# one alias mounts a config over that path.

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /work
        tag: effector
        env: {
            CARGO_HOME: '/opt/cargo'
            EFFECTOR_RESOURCES_ROOT: '/work/resources'
        }
    }
    | merge $context
    | build {|ctx|
        b conf env $ctx.env
        b conf path [ ($ctx.env.CARGO_HOME)/bin ]

        # `rust` (the distro package) rather than `rustup`: Arch tracks upstream stable —
        # 1.100.0 at the time of writing, the same release rustup would download — and the
        # package mirror is a static, already-signed source, so the build does not spend
        # minutes pulling a toolchain per run. gcc is the linker cargo's default driver
        # expects. The toolchain is both this image's build input and what delivered Rust
        # scripts compile against.
        pkg install [rust gcc git curl ca-certificates rustic]

        # The runtime crate path-depends on the sibling `induction` workspace
        # (crates/runtime/Cargo.toml -> ../../../induction/...), so the checkout layout is
        # a build fact, not a preference: <root>/effector next to <root>/induction.
        b exec [
            'mkdir -p /src'
            'git clone --depth 1 https://github.com/orbsh/effector /src/effector'
            'git clone --depth 1 https://github.com/orbsh/induction /src/induction'
            'cd /src/effector && CARGO_TARGET_DIR=/build cargo build --release --features python'
        ]

        # Which commit this binary came from — the only thing that makes a shipped node
        # auditable against its source.
        let rev = (b exec ['git -C /src/effector rev-parse --short HEAD'] | str trim)
        b conf env { EFFECTOR_REV: $rev }

        # The runners are FIXED deployment artifacts (gravity ADR-0001 §4): a node mount's
        # source is one of these commands, and the operation's script arrives as an argument.
        b exec [
            'install -Dm755 /build/release/effector /usr/local/bin/effector'
            'mkdir -p /opt/effector/runners'
            'cp /src/effector/deploy/runners/* /opt/effector/runners/'
            'rm -rf /src /build'
            $'rm -rf ($ctx.env.CARGO_HOME)/registry/* ($ctx.env.CARGO_HOME)/git/*'
            $'chown master:master -R ($ctx.env.CARGO_HOME) /opt/effector'
        ]

        b with-mount {
            mkdir work/resources
            r#'{
  "control_plane_url": "ws://127.0.0.1:8787",
  "class": "container",
  "token": "",
  "lease": {
    "idle_secs": 15,
    "max_idle_secs": 300,
    "exit_on_disconnect": true
  },
  "capabilities": {
    "node_alias": "",
    "carriers": ["steel", "python", "induction", "exec"]
  }
}'# | save -f work/effector.json
        }

        b exec ['chown master:master -R /work']

        b conf workdir /work
        b conf cmd ['effector']
    }
}