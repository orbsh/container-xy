use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):deb'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        pkg setup py [
            httpx aiofile aiostream
            fastapi uvicorn[standard]
            pytest pydantic pydantic-graph
            PyParsing jinja2
            typer pydantic-settings pyyaml
            boltons decorator
            agno openai
            zstandard
        ]
    }
}
