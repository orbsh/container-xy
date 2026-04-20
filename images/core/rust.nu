use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
        rust: {
            channel: stable
        }
        env: {
            RUSTUP_HOME: '/opt/rustup'
            CARGO_HOME: '/opt/cargo'
        }
    }
    | merge $context
    | build {|ctx|
        conf env $ctx.env

        pkg install [
            rustup lldb
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


        match $ctx.rust.frontend? {
            'leptos' => {
                $bins ++= [cargo-leptos]
            }
            'dioxus' => {
                $bins ++= [dioxus-cli]
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
            bacon cross bugstalker
            cargo-pgo cargo-bloat # cargo-profiler
            cargo-expand cargo-eval cargo-tree
            cargo-feature cargo-edit cargo-rail
            trunk cargo-wasi
            wasm-tools wit-deps-cli wit-bindgen-cli
            ...$bins
        ] --cargo-home $ctx.env.CARGO_HOME

        let ui = if ($ctx.rust.frontend? | is-empty) { [] } else { [frontend ui-($ctx.rust.frontend)] }
        rust prefetch $ctx.user $ctx.workdir 'rust-labs' --stack [
            experimental ...$ui
            cli error meta utils parser data http serde
            tracing ml parallel async concurrency web
            ecs wasm script system
        ] --cargo-home $ctx.env.CARGO_HOME
    }
}
