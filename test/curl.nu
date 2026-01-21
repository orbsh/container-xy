use ../libs *

export def main [context: record = {}] {
    {
        from: 'debian:sid-slim'
        author: unnamed
        timezone: Asia/Shanghai
        user: master
        workdir: /home/master
        image: test
        tags: z
    }
    | merge $context
    | build {|ctx|
        pkg install [curl zstd sudo]
    }
}
