# source test/env.nu

use ../libs *

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
| build --export {|ctx| }
