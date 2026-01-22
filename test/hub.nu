use ../libs *

export def main [context: record = {}] {
    {
        from: 'xy'
        author: unnamed
        timezone: Asia/Shanghai
        user: master
        workdir: /home/master
        image: test
        tags: x
    }
    | merge $context
    | build {|ctx|
        hub install -c $ctx.cache? [helix]
    }
}
