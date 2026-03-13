use ../../bx *


export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master/openclaw
    }
    | merge $context
    | merge { tag: openclaw }
    | build {|ctx|
        conf user master
        conf workdir $ctx.workdir
        conf env {
            NODE_LLAMA_CPP_SKIP_DOWNLOAD: 'true'
            OPENCLAW_ALLOW_INSECURE_PRIVATE_WS: '1'
            OPENCLAW_HOME: $ctx.workdir
            OPENCLAW_CONFIG_PATH: ($ctx.workdir | path join openclaw.json)
        }

        run [
            $'mkdir ($ctx.workdir)'
            $'cd ($ctx.workdir)'
            # 'npm install --no-cache --omit=optional openclaw'
            'npm install --no-cache openclaw'
            'rm -rf node_modules/@node-llama-cpp node_modules/node-llama-cpp'
        ]

        copy images/tools/entrypoint/openclaw.nu /entrypoint/openclaw.nu

        conf expose [18789]
        conf cmd ['srv']
    }
}
