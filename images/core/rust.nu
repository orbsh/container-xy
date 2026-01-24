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
        ]

        mut cmps = []
        if $ctx.rust.channel == 'nightly' {
            $cmps ++= [rustc-codegen-cranelift]
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
            rust-script trunk cargo-wasi
            wasm-tools wit-deps-cli wit-bindgen-cli
            #dioxus-cli
            #cargo-leptos
        ]
        rust prefetch $ctx.user $ctx.workdir 'cargo-fetch' [
            clap figment knuffel kdl toml tempdir
            snafu anyhow thiserror
            proc-macro2 syn quote macro_rules_attribute
            linkme regex jiff moka bumpalo
            bon indoc itertools derive_more
            refined_type dashmap indexmap maplit arc-swap bitflags num
            url reqwest scraper markdown
            serde serde_derive serde_with serde_json_path
            serde_json postcard serde_cbor schemars serde_yaml
            tracing tracing-subscriber tracing-serde
            rayon polars nalgebra linfa burn
            crossbeam parking_lot specs
            nom minijinja wasmtime wasmi koto
            notify listenfd libc mimalloc
            tokio tokio-util tokio-tungstenite smol async-compat
            futures futures-util async-stream async-trait
            async-fs async-graphql sqlx
            warp async-graphql-warp
            axum async-graphql-axum
            # wasm-pack wee_alloc leptos
            wasm-bindgen wasm-bindgen-futures wasm-logger
            #dioxus dioxus-web
            sycamore gloo-net
        ]
    }
}
