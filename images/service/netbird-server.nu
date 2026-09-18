use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):deb'
        user: master
        workdir: /data
        tag: netbird-server
    }
    | merge $context
    | build {|ctx|
        pkg install [ca-certificates]
        hub install [netbird-server] -c $ctx.cache?

        b conf expose [80 u3478]

        b with-mount {
            r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            # ------------------------------------------------------------------
            # NetBird combined server (management + signal + relay + STUN),
            # embedded IdP (Dex) always enabled — issuer = exposedAddress + /oauth2.
            # TLS is terminated upstream by the gateway: plaintext HTTP on :80
            # (gRPC multiplexed via HTTP/2 cleartext, h2c from Envoy Gateway).
            # Config is regenerated on every boot from NB_* env (single source
            # of truth); state (sqlite db, idp.db, keys) lives in NB_DATA and
            # is never touched.
            #
            # NB_SERVER_URL        -> public base URL, e.g. https://nb.example.com
            #                         (required; exposedAddress + auth issuer)
            # NB_DATA              -> data dir for store.db/idp.db/letsencrypt
            #                         (default /data)
            # NB_RELAY_AUTH_SECRET -> relay shared secret (required for local relay)
            # NB_STORE_ENCRYPTION_KEY
            #                      -> store encryption key (required)
            # NB_STUN_PORT         -> local STUN port (default 3478)
            # NB_LOG_LEVEL         -> logLevel (default info)
            # NB_DASHBOARD_URL     -> dashboard public URL; defaults to server URL
            # NB_DISABLE_METRICS   -> "true" disables anonymous metrics (default true)
            # NB_DISABLE_GEOLITE   -> "true" disables geolite updates (default false)
            # ------------------------------------------------------------------

            def build-config [server_url: string, data: string] {
                let dashboard_url = ($env.NB_DASHBOARD_URL? | default $server_url)
                mut config = {
                    server: {
                        listenAddress: ":80"
                        exposedAddress: $"($server_url):443"
                        stunPorts: [($env.NB_STUN_PORT? | default 3478 | into int)]
                        metricsPort: 9090
                        healthcheckAddress: ":9000"
                        logLevel: ($env.NB_LOG_LEVEL? | default "info")
                        logFile: "console"
                        # TLS terminated upstream by the gateway
                        tls: { certFile: "", keyFile: "" }
                        authSecret: ($env.NB_RELAY_AUTH_SECRET?
                            | default { error make { msg: "NB_RELAY_AUTH_SECRET is required (openssl rand -base64 32)" } })
                        dataDir: $data
                        disableAnonymousMetrics: (($env.NB_DISABLE_METRICS? | default "true") == "true")
                        disableGeoliteUpdate: (($env.NB_DISABLE_GEOLITE? | default "false") == "true")
                        auth: {
                            # embedded IdP issuer: own public address + /oauth2
                            issuer: $"($server_url)/oauth2"
                            localAuthDisabled: false
                            signKeyRefreshEnabled: true
                            dashboardRedirectURIs: [
                                $"($dashboard_url)/nb-auth"
                                $"($dashboard_url)/nb-silent-auth"
                            ]
                            cliRedirectURIs: ["http://localhost:53000/"]
                        }
                        store: {
                            engine: "sqlite"
                            dsn: ""
                            encryptionKey: ($env.NB_STORE_ENCRYPTION_KEY?
                                | default { error make { msg: "NB_STORE_ENCRYPTION_KEY is required (openssl rand -base64 32)" } })
                        }
                    }
                }
                $config
            }

            let data = ($env.NB_DATA? | default "/data")
            let server_url = $env.NB_SERVER_URL?
            if ($server_url | is-empty) {
                error make { msg: "NB_SERVER_URL is required, e.g. https://nb.example.com" }
            }

            mkdir $data
            let cfg = ($data | path join config.yaml)

            # regenerate every boot from env; state files untouched
            build-config $server_url $data | to yaml | save -f $cfg
            print $"Generated netbird config: ($cfg)"
            print $"exposedAddress = ($server_url)"

            tasks spawn {
                tag: netbird-server
                msg: $"Starting netbird-server: ($cfg)"
                cmd: [
                    /usr/local/bin/netbird-server
                    --config $cfg
                ]
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save entrypoint/netbird-server.nu
        }

        b conf workdir $ctx.workdir
        b conf cmd ['srv']
    }
}
