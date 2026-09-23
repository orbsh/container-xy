use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):deb'
        user: master
        workdir: /data
        tag: netbird-client
    }
    | merge $context
    | build {|ctx|
        pkg install [ca-certificates]
        hub install [netbird] -c $ctx.cache?

        b conf expose [1055 1056]

        b with-mount {
            r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            # ------------------------------------------------------------------
            # NetBird client (netbird up) connecting to a self-hosted management
            # server. Stateless by design: state lives in emptyDir/tmpfs and the
            # peer re-registers on every boot via a reusable setup key.
            #
            # NB_MANAGEMENT_URL  -> management server gRPC/HTTP address (required)
            #                       e.g. netbird.example.com:443 or https://...
            # NB_SETUP_KEY       -> setup key (reusable, server dashboard generated)
            # NB_HOSTNAME        -> fixed peer name; same name re-registers
            # NB_LOG_LEVEL       -> log level (default info)
            # NB_EXTRA_ARGS      -> extra `netbird up` flags, comma-separated
            # ------------------------------------------------------------------

            def up-args [] {
                mut args = [
                    $"--management-url=($env.NB_MANAGEMENT_URL)"
                ]
                let hostname = ($env.NB_HOSTNAME?)
                if ($hostname | is-not-empty) {
                    $args = ($args | append $"--hostname=($hostname)")
                }
                let extra = ($env.NB_EXTRA_ARGS? | default "" | split row "," | where {|x| $x != ""})
                $args | append $extra
            }

            let setup_key = $env.NB_SETUP_KEY?
            if ($setup_key | is-empty) {
                error make { msg: "NB_SETUP_KEY is required (reusable setup key)" }
            }
            if ($env.NB_MANAGEMENT_URL? | is-empty) {
                error make { msg: "NB_MANAGEMENT_URL is required" }
            }

            let state = ($env.NB_STATE_DIR? | default "/var/lib/netbird")
            mkdir $state

            let args = up-args

            # netbird v0.5x+ 没有 bare `start`：CLI 依赖 daemon（service run），
            # 或用 `up --foreground-mode` 单进程前台连接（容器形态，无 systemd）。
            # flags 同时接受 NB_* env（SetFlagsFromEnvVars），这里显式传参更直观
            tasks spawn {
                tag: netbird-client
                msg: $"Connecting to ($env.NB_MANAGEMENT_URL) as ($env.NB_HOSTNAME?)"
                cmd: [
                    /usr/local/bin/netbird
                    up
                    --foreground-mode
                    --setup-key=($setup_key)
                    ...$args
                ]
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save entrypoint/netbird-client.nu
        }

        b conf workdir $ctx.workdir
        b conf cmd ['srv']
    }
}
