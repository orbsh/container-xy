use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: zeroclaw }
    | build {|ctx|
        hub install -c $ctx.cache? [zeroclaw lightpanda]
        with-mount {

            let tmpl = r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            if ($env.ZEROCLAW_API_KEY? | is-empty) and ($env.API_KEY? | is-empty) {
                print 'Please set ZEROCLAW_API_KEY or API_KEY environment variable'
                return
            }

            let conf = $env.HOME | path join .zeroclaw/config.toml

            if not ($conf | path exists) {
                zeroclaw onboard
            }

            mut cfg = open $conf

            $cfg.default_provider = $env.DEFAULT_PROVIDER? | default 'custom:https://dashscope.aliyuncs.com/compatible-mode/v1'
            $cfg.default_model = $env.DEFAULT_MODEL? | default 'qwen3.5-122b-a10b'

            $cfg.gateway.host = '0.0.0.0'
            $cfg.gateway.port = $env.GATEWAY_PORT? | default '42617' | into int

            $cfg.browser = {
                enable: true
                allowed_domains: ["*"]
                backend: "agent_browser"
                native_headless: true
                native_webdriver_url: "http://127.0.0.1:9222"
            }

            $cfg | to toml | save -f $conf


            tasks spawn {
                tag: zeroclaw
                cmd: 'zeroclaw gateway'
            }
            '#
            | str trim
            | str replace -rma '^ {12}' ''
            | save entrypoint/zeroclaw.nu
        }

        conf expose [42617]
        conf cmd ['srv']
    }
}
