use ../../bx *

def derive [context src tag pkg] {
    {
        from: $'($context.image):($src)'
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
    mut from = 'deb'
    for i in [
        [py]
        [py-data polars lancedb zstandard]
        [py-hermes openai agno git+https://github.com/NousResearch/hermes-agent.git]
    ] {
        let tag = $i.0
        derive $context $from $tag ($i | skip 1)
        $from = $tag
    }
}
