use ../../bx *


export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /app/data
    }
    | merge $context
    | merge { tag: openclaw }
    | build {|ctx|
        conf env {
            NODE_LLAMA_CPP_SKIP_DOWNLOAD: 'true'
            OPENCLAW_ALLOW_INSECURE_PRIVATE_WS: '1'
            OPENCLAW_HOME: $ctx.workdir
            OPENCLAW_CONFIG_PATH: ($ctx.workdir | path join openclaw.json)
        }

        let skills = [
            self-improving
            duckduckgo-websearch
        ]
        | each {|x|
            $'./node_modules/.bin/clawdhub install ($x)'
        }
        run [
            'mkdir -p /app/data'
            'cd /app'
            'chown -R master:master data'
            # 'npm install --no-cache --omit=optional openclaw'
            'npm install --no-cache openclaw clawhub'
            'rm -rf node_modules/@node-llama-cpp node_modules/node-llama-cpp'
            # 'clawhub config set registry https://clawhub-mirror.aliyuncs.com'
            ...$skills
        ]

        conf user master
        conf workdir $ctx.workdir
        copy images/tools/entrypoint/openclaw.nu /entrypoint/openclaw.nu

        conf expose [18789]
        conf cmd ['srv']
    }
}
