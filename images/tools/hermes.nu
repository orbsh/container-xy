use ../../bx *


export def main [context: record = {}] {
    {
        from: $'($context.image):py-duckdb'
        workdir: /app/data
    }
    | merge $context
    | merge { tag: hermes }
    | build {|ctx|
        conf env {
            HERMES_HOME: $ctx.workdir
        }

        pkg install [git]

        pkg py install [
            html2txt
            openai agno
            git+https://github.com/NousResearch/hermes-agent.git
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
