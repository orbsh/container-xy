#!/usr/bin/env nu
use libs/tasks.nu


let d = $env.HOME | path join .openclaw
mkdir $d
let conf = $d | path join config.toml

if not ($conf | path exists) {
    mut cfg = {}

}


# tasks spawn {
#     tag: openclaw
#     cmd: 'openclaw gateway'
# }
