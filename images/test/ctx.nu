use ../../libs *

export def main [context: record = {}] {
    {
        from: 'xy:sid'
        author: unnamed
        timezone: Asia/Shanghai
        user: master
        workdir: /home/master
        image: test
        tags: x
    }
    | merge $context
    | build --skip-push {|ctx|
        hub install -c $ctx.cache? [duckdb jujutsu]
    }

    {
        from: 'xy:ferron'
        author: unnamed
        timezone: Asia/Shanghai
        user: master
        workdir: /home/master
        image: test
        tags: y
    }
    | merge $context
    | build --skip-push {|ctx|
        hub install [duckdb jujutsu] -c $ctx.cache? -t /opt/vessel --archive
    }
}
