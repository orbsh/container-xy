use ../../bx *

def derive [context src layer] {
    {
        from: $'($context.image):($src)'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: $layer.tag }
    | build {|ctx|
        if ($layer.pkgs | any {|x| $x | str starts-with git+https}) {
            pkg with [git] {
                pkg setup py --stack $layer.stack $layer.pkgs
            }
        } else {
            pkg setup py --stack $layer.stack $layer.pkgs
        }
    }
}

export def main [context: record = {}] {
    mut from = 'deb'
    for i in [
        [tag pkgs stack];
        [py [] [web dev io cli utils logging codec]]
        [py-data [polars lancedb zstandard] []]
    ] {
        derive $context $from $i
        $from = $i.tag
    }

    derive $context py {
        tag: py-agent
        pkgs: [openai agno git+https://github.com/NousResearch/hermes-agent.git]
        stack: []
    }
}
