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

        # GeoLite2 预置：首次启动 netbird 会同步下载 GeoLite2（33MB mmdb + 50MB CSV），
        # 国内网络下载不完导致启动被 liveness probe 反复杀（NB_DISABLE_GEOLOCATION
        # 是全量禁用，geolocation 功能没了）。构建期下载并导入 geonames sqlite，
        # 运行时 entrypoint 拷到 $NB_DATA，netbird 见文件存在即跳过下载。
        #
        # with-mount 在宿主机执行、相对路径落在容器挂载点：下载 / 解包 / sqlite 导入
        # 全部用宿主机工具完成，产物直接写进镜像 /opt/geo。镜像里不留 sqlite3/unzip，
        # 也不需要事后再 purge。
        b with-mount {
            let base = 'https://pkgs.netbird.io/geolocation-dbs'
            let stage = (mktemp -t -d --suffix .geolite)
            trace o -p geolite $stage

            curl -fsSL --retry 3 -o ($stage | path join city.tar.gz) $'($base)/GeoLite2-City/download?suffix=tar.gz'
            curl -fsSL --retry 3 -o ($stage | path join csv.zip) $'($base)/GeoLite2-City-CSV/download?suffix=zip'

            # 日期取自 tarball 顶层目录名，netbird 按 GeoLite2-City_<date> 匹配文件
            let top = (tar tzf ($stage | path join city.tar.gz) | lines | first | split row '/' | first)
            let date = ($top | parse 'GeoLite2-City_{date}' | get 0.date)
            trace o -p geolite { date: $date }

            mkdir opt/geo
            mkdir ($stage | path join city)
            tar zxf ($stage | path join city.tar.gz) -C ($stage | path join city)
            cp ($stage | path join city $top GeoLite2-City.mmdb) $'opt/geo/GeoLite2-City_($date).mmdb'

            unzip -q ($stage | path join csv.zip) -d ($stage | path join csv)
            let csvdir = (ls ($stage | path join csv) | where type == dir | get name | first)
            let db = $'opt/geo/geonames_($date).db'
            sqlite3 $db 'CREATE TABLE geonames (geoname_id integer, locale_code text, continent_code text, continent_name text, country_iso_code text, country_name text, subdivision_1_iso_code text, subdivision_1_name text, subdivision_2_iso_code text, subdivision_2_name text, city_name text, metro_code text, time_zone text, is_in_european_union text);'
            # 导入 CSV：跳过 header，14 列
            sqlite3 -csv $db $'.import --skip 1 ($csvdir | path join GeoLite2-City-Locations-en.csv) geonames'
            sqlite3 $db 'CREATE INDEX idx_geonames_country_iso_code ON geonames(country_iso_code); CREATE INDEX idx_geonames_geoname_id ON geonames(geoname_id);'

            trace o -p geolite (ls opt/geo | get name)
            rm -rf $stage
        }

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

            # 预置 GeoLite2：构建期已放在 /opt/geo，拷到数据目录后 netbird 检测
            # 到文件存在即跳过启动期下载（文件名含日期，匹配 netbird 的 glob）
            let geo_src = '/opt/geo'
            if ($geo_src | path exists) {
                ls $'($geo_src)/*' | each {|f|
                    let dst = ($data | path join $f.name)
                    if not ($dst | path exists) {
                        cp $f.name $dst
                        print $"staged geolite: ($f.name)"
                    }
                }
            }

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
