use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):deb'
        user: master
        workdir: /data
        tag: tailscale
    }
    | merge $context
    | build {|ctx|
        pkg install [ca-certificates iptables]
        hub install [tailscale] -c $ctx.cache?

        b conf expose [1055 1056]

        b with-mount {
            r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            # ------------------------------------------------------------------
            # Tailscale client (tailscaled) connecting to a headscale control
            # plane. Stateless by design: state lives in a tmpfs/emptyDir and
            # the node re-registers on every boot via a REUSABLE preauth key.
            #
            # TS_LOGIN_SERVER  -> headscale URL (required)
            # TS_AUTHKEY       -> preauth key, MUST be --reusable for stateless
            # TS_HOSTNAME      -> fixed node name; same name re-registers on
            #                     the same node record instead of piling up
            # TS_ACCEPT_DNS    -> "true" lets the tailnet own DNS (default false)
            # TS_EXTRA_ARGS    -> extra `tailscale up` flags, comma-separated
            # TS_ROUTES        -> subnet routes to advertise, comma-separated
            # TS_SOCKS5_SERVER / TS_OUTBOUND_HTTP_PROXY_LISTEN
            #                  -> userspace proxy listeners (default :1055/:1056)
            # TS_AUTH_ONCE     -> "true" only auth on first boot (needs
            #                     persistent state, NOT for stateless use)
            # ------------------------------------------------------------------

            def up-args [] {
                mut args = [
                    $"--login-server=($env.TS_LOGIN_SERVER)"
                    $"--hostname=($env.TS_HOSTNAME? | default ($env.HOSTNAME? | default tailscale-node))"
                ]
                if (($env.TS_ACCEPT_DNS? | default "false") == "true") {
                    $args = ($args | append "--accept-dns=true")
                } else {
                    $args = ($args | append "--accept-dns=false")
                }
                let routes = ($env.TS_ROUTES? | default "")
                if ($routes | is-not-empty) {
                    $args = ($args | append $"--advertise-routes=($routes)")
                }
                let extra = ($env.TS_EXTRA_ARGS? | default "" | split row "," | where {|x| $x != ""})
                $args | append $extra
            }

            let authkey = $env.TS_AUTHKEY?
            if ($authkey | is-empty) {
                error make { msg: "TS_AUTHKEY is required (reusable preauth key)" }
            }
            if ($env.TS_LOGIN_SERVER? | is-empty) {
                error make { msg: "TS_LOGIN_SERVER is required" }
            }

            let state = ($env.TS_STATE_DIR? | default "/var/lib/tailscale")
            mkdir $state

            let args = up-args

            # wait for the state dir then bring tailscaled up via the wrapper
            tasks spawn {
                tag: tailscaled
                msg: $"Starting tailscaled: login=($env.TS_LOGIN_SERVER) host=($env.TS_HOSTNAME?)"
                cmd: [
                    /usr/local/bin/tailscaled
                    --tun=($env.TS_TUN? | default "userspace-networking")
                    --statedir=($state)
                    --socket=($"($state)/tailscaled.sock")
                    --socks5-server=($env.TS_SOCKS5_SERVER? | default "0.0.0.0:1055")
                    --outbound-http-proxy-listen=($env.TS_OUTBOUND_HTTP_PROXY_LISTEN? | default "0.0.0.0:1056")
                ]
            }

            # tailscale up is retried: control plane may be briefly unreachable
            # at container start; the daemon itself stays managed by tasks.
            tasks spawn {
                tag: tailscale-up
                msg: "Running tailscale up"
                cmd: [
                    /usr/local/bin/tailscale
                    --socket=($"($state)/tailscaled.sock")
                    up
                    --authkey=($authkey)
                    ...$args
                ]
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save entrypoint/tailscale.nu
        }

        b conf workdir $ctx.workdir
        b conf cmd ['srv']
    }
}
