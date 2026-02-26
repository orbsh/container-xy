use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        conf expose [8080]
        conf env {
            HOST: '0.0.0.0'
            PORT: '8080'
        }
        pkg with [ base-devel ] {
            pkg pip install [
                psycopg[binary] lancedb duckdb
                numpy scikit-learn polars[all]
                # httpx aiofile aiostream fastapi uvicorn
                # debugpy pytest pydantic pydantic-graph PyParsing
                # typer pydantic-settings pyyaml
                # boltons decorator
                marimo[recommended,lsp,sql] altair
            ]
            pkg pip install --index-url https://download.pytorch.org/whl/cpu [
                torch torchvision torchaudio
            ]
        }
        with-mount {
            cd entrypoint
            r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            let cmd = [
                marimo edit --no-token
                -p $env.PORT
                --host $env.HOST
            ]
            | str join " "

            tasks spawn {
                tag: marimo
                msg: "Starting marimo."
                cmd: $cmd
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save marimo.nu
        }
        conf cmd ['srv']
        conf user master
    }
}
