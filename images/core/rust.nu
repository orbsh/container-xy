use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
        rust: {
            channel: stable
        }
    }
    | merge $context
    | build {|ctx|
        conf env {
            RUSTUP_HOME: '/opt/rustup'
            CARGO_HOME: '/opt/cargo'
            RUSTC_WRAPPER: '/usr/bin/sccache'
        }

        pkg install [
            rustup lldb sccache
            musl
        ]

        mut cmps = []
        if $ctx.rust.channel == 'nightly' {
            $cmps ++= [rustc-codegen-cranelift]
        }

        mut bins = []
        if $ctx.rust.channel == 'nightly' {
            $bins ++= []
        } else {
            $bins ++= [rust-script]
        }

        mut experimental = [
            rkyv # Zero-copy deserialization framework
            dumpster # Cycle-tracking garbage collector library
        ]

        mut frontend = [
            wasm-bindgen wasm-bindgen-futures
            wasm-logger gloo-net
        ]
        match $ctx.rust.frontend? {
            'leptos' => {
                $frontend ++= [wasm-pack wee_alloc leptos]
                $bins ++= [cargo-leptos]
            }
            'dioxus' => {
                $frontend ++= [dioxus dioxus-web]
                $bins ++= [dioxus-cli]
            }
            _ => {
                $frontend ++= [sycamore]
            }
        }

        rust up $ctx.user $ctx.rust.channel --component [
            rust-src clippy rustfmt
            rust-analyzer
            ...$cmps
        ] --target [
            x86_64-unknown-linux-musl
            wasm32-wasip1 wasm32-wasip2 wasm32-unknown-unknown
        ] --bin [
            bacon cross
            cargo-pgo cargo-bloat # cargo-profiler
            cargo-expand cargo-eval cargo-tree
            cargo-feature cargo-edit cargo-rail
            trunk cargo-wasi
            wasm-tools wit-deps-cli wit-bindgen-cli
            ...$bins
        ]
        rust prefetch $ctx.user $ctx.workdir 'rust-labs' [
            ...$experimental
            ...$frontend
            clap figment knuffel kdl toml tempdir
            snafu anyhow thiserror
            proc-macro2 syn quote macro_rules_attribute
            linkme regex jiff moka bumpalo
            nom minijinja bon indoc itertools derive_more
            refined_type dashmap indexmap maplit arc-swap bitflags num
            url reqwest scraper markdown
            serde serde_derive typetag serde_with serde_json_path
            serde_json postcard serde_cbor schemars serde_yaml
            tracing tracing-subscriber tracing-serde
            rayon polars nalgebra linfa burn plotlars
            crossbeam parking_lot specs
            wasmtime wasmi steel-core steel-repl koto rune
            notify listenfd libc mimalloc
            tokio tokio-util tokio-tungstenite smol async-compat
            futures futures-util async-stream async-trait
            async-fs async-graphql sqlx
            # warp async-graphql-warp
            axum async-graphql-axum
        ]
    }
}
