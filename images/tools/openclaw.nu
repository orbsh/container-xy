use ../../bx *


export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: openclaw }
    | build {|ctx|
        conf user master
        conf env {
            OPENCLAW_CONFIG_PATH: /home/master/openclaw/openclaw.json
        }

        run [
            'mkdir openclaw'
            'cd openclaw'
            'npm install --no-cache openclaw'
        ]

        copy images/tools/entrypoint/openclaw.nu /entrypoint/openclaw.nu

        conf expose [18789]
        conf cmd ['srv']
    }
}
