use ../../bx *

def derive [context tag pkg] {
    {
        from: $'($context.image):deb'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: $tag }
    | build {|ctx|
        pkg with [
            git
        ] {
            pkg setup py --stack [
                web dev io cli utils logging codec
            ]  $pkg
        }
    }
}

export def main [context: record = {}] {
    for i in [
        [py]
        [py-agno openai agno]
        [py-data polars lancedb zstandard]
        [py-hermes openai git+https://github.com/NousResearch/hermes-agent.git]
    ] {
        derive $context $i.0 ($i | skip 1)
    }
}
