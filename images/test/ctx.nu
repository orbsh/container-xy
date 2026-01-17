use ../../libs *

export def main [context: record = {}] {
    {
        from: 'xy:sid'
        author: unnamed
        timezone: Asia/Shanghai
        user: master
        workdir: /home/master
        image: test
    }
    | merge $context
    | build --skip-push {|ctx|
        hub install [duckdb]
    }
}
