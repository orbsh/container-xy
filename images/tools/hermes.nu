use ../../bx *


export def main [context: record = {}] {
    {
        from: $'($context.image):py-duckdb'
        workdir: /app/data
    }
    | merge $context
    | merge { tag: hermes }
    | build {|ctx|
        b conf env {
            HERMES_HOME: $ctx.workdir
        }

        pkg install [git]

        pkg py install [
            html2txt ddgr
            openai agno
            git+https://github.com/NousResearch/hermes-agent.git
        ]

        let ports = {
            web_ui: 9119
            api_server: 8642
            webhook: 8644
        }
        | values

        b conf expose $ports

        b copy images/tools/entrypoint/hermes.nu /entrypoint/hermes.nu

        b conf cmd ['srv']
    }
}
