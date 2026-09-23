use ../../bx *

export def main [context: record = {}] {
    {
        # deb 基础镜像 + apt 安装 nginx：单 listener 混跑 h1 与 h2c（nginx 按协议
        # 分流，不互斥），前端形态对齐 netbird 官方 nginx.tmpl.conf 的单 nginx 方案。
        from: $'($context.image):deb'
        user: master
        workdir: /data
        tag: netbird-server
    }
    | merge $context
    | build {|ctx|
        pkg install [ca-certificates nginx]
        hub install [netbird-server] -c $ctx.cache?
        # dashboard SPA（Next.js 静态导出）落到 /srv/dashboard，nginx 直接服务。
        # 镜像以 root 运行（deb 基础镜像只建 master 用户，不设容器用户；除非定义里显式
        # b conf user），所以 entrypoint 运行期直接改写这些资产，不需要 chown。
        # 若将来给本镜像加 b conf user master，需同时把 /srv/dashboard chown 过去。
        hub install [netbird-dashboard] -t /srv/dashboard

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

        # 80   = nginx（单一入口：h1 + h2c 混跑 —— dashboard 静态 + /api /oauth2
        #        /relay /ws-proxy 的 h1 代理、gRPC 前缀的 grpc_pass，全部一个 listener）
        # 8080 = netbird 本体（h2c 上游，nginx 回源；不再由网关直连）
        b conf expose [80 8080 u3478]

        # nginx 配置（镜像内 /srv/nginx/dashboard.conf）。
        #
        # 为什么回到单端口：ferron 一个明文 listener 无法同时接受 h1 与 h2c
        # （"Plaintext HTTP/1.x and HTTP/2 over cleartext are mutually exclusive"），
        # 只好让网关按前缀把 gRPC 直连 8080。nginx 明文 listener 能按连接协商
        # h1/h2c（grpc location 走 h2c、proxy location 走 h1），单端口承载全部路径，
        # 网关侧不再需要 gRPC 直连路由。
        #
        # 形态对齐上游 infrastructure_files/nginx.tmpl.conf：SPA 静态在 location /，
        # proxy location 用 proxy_http_version 1.1 + Upgrade 头透传 WebSocket，
        # gRPC location 用 grpc_pass（长超时防连接早断）。SPA 路由（/invite/ 等）
        # 用 try_files 落到 <route>.html —— query string 不参与 try_files 匹配，
        # ferron rewrite 的两个坑（尾斜杠、query）在这里结构性消失。
        b with-mount {
            mkdir srv/nginx
            r#'
            # Next.js 静态导出：每个路由是 <route>.html；try_files $uri $uri.html
            # =404 等价物。query string 不参与 try_files 匹配，尾斜杠由
            # $uri.html 兜住（/invite/?token=... → /invite.html）
            map $http_upgrade $connection_upgrade {
                default upgrade;
                ''      close;
            }
            server {
                listen 80;
                listen 80 http2;
                root /srv/dashboard;

                # gRPC 长连接不能被默认 60s 头超时掐断
                client_header_timeout 1d;
                client_body_timeout 1d;

                proxy_set_header   X-Real-IP $remote_addr;
                proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header   X-Forwarded-Proto $scheme;
                proxy_set_header   X-Forwarded-Host $host;
                grpc_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;

                # Management grpc
                location /management.ManagementService/ {
                    grpc_pass grpc://127.0.0.1:8080;
                    grpc_read_timeout 1d;
                    grpc_send_timeout 1d;
                    grpc_socket_keepalive on;
                }
                # Signal grpc
                location /signalexchange.SignalExchange/ {
                    grpc_pass grpc://127.0.0.1:8080;
                    grpc_read_timeout 1d;
                    grpc_send_timeout 1d;
                    grpc_socket_keepalive on;
                }
                # Management api（/api 由 netbird 自带，/oauth2 是 embedded Dex）
                location /api/ {
                    proxy_pass http://127.0.0.1:8080;
                    proxy_set_header Host $host;
                }
                location /oauth2/ {
                    proxy_pass http://127.0.0.1:8080;
                    proxy_set_header Host $host;
                }
                # Relay（WebSocket 升级）
                location /relay {
                    proxy_pass http://127.0.0.1:8080;
                    proxy_http_version 1.1;
                    proxy_set_header Upgrade $http_upgrade;
                    proxy_set_header Connection $connection_upgrade;
                    proxy_set_header Host $host;
                }
                # Management/Signal wsproxy（WebSocket 升级）
                location /ws-proxy/ {
                    proxy_pass http://127.0.0.1:8080;
                    proxy_http_version 1.1;
                    proxy_set_header Upgrade $http_upgrade;
                    proxy_set_header Connection $connection_upgrade;
                    proxy_set_header Host $host;
                }
                # dashboard SPA：静态导出 + 路由改写
                location / {
                    try_files $uri $uri.html =404;
                }
                error_page 404 /404.html;
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save srv/nginx/dashboard.conf
        }

        # nginx 启动脚本：apt 版 nginx 需要显式指定配置（系统默认 /etc/nginx 会
        # 带起 site-enabled 默认站点）。-g daemon off 前台运行，交给 tasks 框架管理。
        b with-mount {
            r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            tasks spawn {
                tag: nginx
                msg: 'Starting nginx: dashboard front on :80'
                # nushell list 传参不做 shell 分词：一个完整字符串元素即可，
                # 反斜杠转义会被字面传入（nginx 报 invalid option: "off\""）
                cmd: [
                    /usr/sbin/nginx
                    -c /srv/nginx/dashboard.conf
                    -e /dev/stderr
                    -g 'daemon off;'
                ]
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save -f entrypoint/nginx.nu
        }

        b with-mount {
            r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            # ------------------------------------------------------------------
            # NetBird combined server (management + signal + relay + STUN),
            # embedded IdP (Dex) always enabled — issuer = exposedAddress + /oauth2.
            # TLS is terminated upstream by the gateway: plaintext HTTP on :8080
            # (gRPC multiplexed via HTTP/2 cleartext, h2c).
            # The dashboard SPA and the h1 API surface are served by nginx on
            # :80 in the same container (see /srv/nginx/dashboard.conf): nginx
            # proxies /api /oauth2 /relay /ws-proxy here and grpc_pass the gRPC
            # prefixes; the gateway only ever talks to :80.
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
                        listenAddress: ":8080"
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

            # 预置 GeoLite2：构建期已放在 /opt/geo，运行期无条件覆盖数据目录里的同名文件。
            # 不用"不存在才拷"：netbird 启动期自己下载若中途被打断，会在同一文件名下留
            # 半成品（文件名带日期，与镜像副本同名），存在性判断会让它一直用坏文件；镜像
            # 里的副本是已知良好的，覆盖安全。版本升级时文件名带新日期，不会互相覆盖。
            let geo_src = '/opt/geo'
            if ($geo_src | path exists) {
                ls $'($geo_src)/*' | each {|f|
                    # 必须取 basename：ls 给的是绝对路径，path join 遇到绝对路径会把它
                    # 当成结果（不是拼接），直接拼就成了"自己拷自己"（cp-error-same-file）
                    let name = ($f.name | path basename)
                    cp -f $f.name ($data | path join $name)
                    print $"staged geolite: ($name)"
                }
            }

            let cfg = ($data | path join config.yaml)

            # regenerate every boot from env; state files untouched
            build-config $server_url $data | to yaml | save -f $cfg
            print $"Generated netbird config: ($cfg)"
            print $"exposedAddress = ($server_url)"

            # dashboard 静态导出里的运行期变量：官方 dashboard 容器用 envsubst 注入，
            # 这里等价地在 boot 期替换。值全部由 NB_SERVER_URL 推导（SPA 与 API 同源，
            # nginx :80 同时服务静态并代理 /api）。占位符形如 "$AUTH_AUTHORITY"，
            # 只替换下表列出的变量名——chunk 里还有 $D/$H/$W 这类压缩变量，不能碰。
            let dash = '/srv/dashboard'
            if ($dash | path exists) {
                let vars = {
                    NETBIRD_MGMT_API_ENDPOINT: $server_url
                    NETBIRD_MGMT_GRPC_API_ENDPOINT: $server_url
                    AUTH_AUTHORITY: $"($server_url)/oauth2"
                    AUTH_CLIENT_ID: "netbird-dashboard"
                    AUTH_CLIENT_SECRET: ""
                    # embedded IdP 无 audience（官方 configure.sh: audience=none）
                    AUTH_AUDIENCE: ""
                    # 与 embedded IdP 的 defaultScopes 一致（idp/embedded.go）
                    AUTH_SUPPORTED_SCOPES: "openid profile email groups"
                    # 这两个必须是 PATH 不是绝对 URL：dashboard 里是
                    # redirect_uri = window.location.origin + config.redirectURI
                    # （OIDCProvider.tsx），给绝对 URL 会拼成
                    # https://hosthttps://host/nb-auth → Dex 报 Unregistered redirect_uri
                    AUTH_REDIRECT_URI: "/nb-auth"
                    AUTH_SILENT_REDIRECT_URI: "/nb-silent-auth"
                    USE_AUTH0: "false"
                    NETBIRD_TOKEN_SOURCE: "accessToken"
                    NETBIRD_CLOUD: "false"
                    NETBIRD_LICENSED: "false"
                    NETBIRD_AGENT_NETWORK_ONLY: "false"
                    NETBIRD_AGENT_NETWORK_ENABLED: "false"
                    NETBIRD_DRAG_QUERY_PARAMS: "false"
                    NETBIRD_AUTH_SERVICE_URL: ""
                    NETBIRD_WASM_PATH: ""
                    NETBIRD_HOTJAR_TRACK_ID: ""
                    NETBIRD_GOOGLE_ANALYTICS_ID: ""
                    NETBIRD_GOOGLE_TAG_MANAGER_ID: ""
                    NETBIRD_ANALYTICS_EXCLUDED_EMAILS: ""
                    NETBIRD_HUBSPOT_PORTAL_ID: ""
                    NETBIRD_HUBSPOT_SIGNUP_FORM_ID: ""
                    NETBIRD_HUBSPOT_ONBOARDING_FORM_ID: ""
                    NETBIRD_HUBSPOT_SURVEY_FORM_ID: ""
                }
                let subst = {|text: string|
                    mut t = $text
                    for k in ($vars | columns) {
                        $t = ($t | str replace --all ('$' + $k) ($vars | get $k))
                    }
                    $t
                }

                let tmpl = ($dash | path join OidcTrustedDomains.js.tmpl)
                if ($tmpl | path exists) {
                    do $subst (open --raw $tmpl) | save -f ($dash | path join OidcTrustedDomains.js)
                }

                # 运行期配置的 JS chunk 按内容定位（文件名带 hash，随 dashboard 版本变）
                let chunks = ls $'($dash)/_next/static/chunks/*.js'
                | where {|f| (open --raw $f.name) | str contains '$AUTH_SUPPORTED_SCOPES' }
                | get name
                if ($chunks | is-empty) {
                    print "dashboard runtime config: 未找到占位符 chunk（已注入过，或 dashboard 占位符布局变了）"
                } else {
                    for f in $chunks {
                        do $subst (open --raw $f) | save -f $f
                        print $"patched dashboard runtime config: ($f)"
                    }
                }
            }

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
