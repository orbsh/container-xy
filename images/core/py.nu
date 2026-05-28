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
                pkg py install --stack $layer.stack $layer.pkgs
            }
        } else {
            pkg py install --stack $layer.stack $layer.pkgs
        }
    }
}

export def main [context: record = {}] {
    {
        from: $'($context.image):deb'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: py }
    | build {|ctx|
        pkg setup py --stack [web dev io cli utils logging codec]
    }

    mut from = 'py'
    for i in [
        [tag pkgs stack];
        [py-data [polars lancedb zstandard] []]
    ] {
        derive $context $from $i
        $from = $i.tag
    }

    {
        from: $'($context.image):py-data'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: py-duckdb }
    | build {|ctx|
        pkg setup py [duckdb]

        [
            httpfs
            vortex
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
