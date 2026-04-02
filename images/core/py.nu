use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):ubuntu'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        pkg setup python [
            httpx aiofile aiostream
            fastapi uvicorn
            pytest pydantic pydantic-graph PyParsing
            typer pydantic-settings pyyaml
            boltons decorator
            agno openai
            zstandard
        ]
    }
}
