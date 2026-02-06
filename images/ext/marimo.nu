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
                psycopg[binary] lancedb
                polars numpy scikit-learn # polars[all]
                # httpx aiofile aiostream fastapi uvicorn
                # debugpy pytest pydantic pydantic-graph PyParsing
                # typer pydantic-settings pyyaml
                # boltons decorator
                deltalake
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
            use init.nu [pueue-spawn now]

            def run-marimo [] {
                [
                    marimo edit --no-token
                    -p $env.PORT
                    --host $env.HOST
                ]
                | str join " "
                | pueue-spawn marimo
            }

            run-marimo
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save marimo.nu
        }
        conf cmd ['srv']
        conf user master
    }
}
