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
        pkg setup py --stack [
            web dev io cli utils logging data codec
        ]  $pkg

    }
}

export def main [context: record = {}] {
    for i in [
        [py]
        [py-agno openai agno]
        [py-hermes openai hermes-agent]
    ] {
        derive $context $i.0 ($i | skip 1)
    }
}
