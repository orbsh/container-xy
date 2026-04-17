use ../../bx *


export def main [context: record = {}] {
    {
        from: $'($context.image):browser'
        workdir: /app/data
    }
    | merge $context
    | merge { tag: hermes }
    | build {|ctx|
        conf env {
            HERMES_HOME: $ctx.workdir
        }

        pkg py install [html2txt]

        let ins = [
            curl -fsSL
            https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh
            '|'
            bash -s -- --no-venv
        ]
        | str join ' '


        conf workdir /opt/hermes-agent

        with-mount {|new, old|
            cd opt
            git clone --depth=1 https://github.com/NousResearch/hermes-agent.git
        }

        run [
            'cd /opt/hermes-agent'
            'pip install --break-system-packages -e .'
        ]


        let ports = {
            web_ui: 9119
            api_server: 8642
            webhook: 8644
        }
        | values
        conf expose $ports

        copy images/tools/entrypoint/hermes.nu /entrypoint/hermes.nu

        conf cmd ['srv']
    }
}
