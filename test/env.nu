use ../libs *

export def --env main [context: record = {}] {
    {
        from: 'xy:z'
        author: unnamed
        timezone: Asia/Shanghai
        user: master
        workdir: /home/master
        image: test
        tags: x
        skip_push: true
    }
    | build --expose {|ctx| }
}
