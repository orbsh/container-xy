use ../libs *

export def main [context: record = {}] {
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
    | build {|ctx|
        hub install [duckdb jujutsu] -c $ctx.cache? -t /opt/vessel --bundle
    }
}
