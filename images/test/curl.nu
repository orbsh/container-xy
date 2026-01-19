use ../../libs *

export def main [context: record = {}] {
    {
        from: 'debian:sid-slim'
        author: unnamed
        timezone: Asia/Shanghai
        user: master
        workdir: /home/master
        image: test
        tags: x
    }
    | merge $context
    | build --skip-push {|ctx|
        pkg install [curl zstd]
    }
}
