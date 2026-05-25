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
        [py-agent [openai agno git+https://github.com/NousResearch/hermes-agent.git] []]
    ] {
        derive $context $from $i
        $from = $i.tag
    }

    {
        from: $'($context.image):py-agent'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: py-duck-agent }
    | build {|ctx|
        pkg setup py [duckdb]

        [
            httpfs
            # vortex
            delta
            ducklake
            iceberg
            lance
            postgres
            mysql
            sqlite
            fts
        ]
        | each {|x|
            $"python3 -c \"import duckdb; duckdb.execute\('INSTALL ($x);'\)\""
        }
        | run $in
    }
}
