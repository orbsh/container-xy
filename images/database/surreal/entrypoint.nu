#!/usr/bin/env nu
use libs/tasks.nu

mut args = $env.ENTRYPOINT_ARGS? | default []
if $args.0? == 'srv' { $args = $args | skip 1 } else { exit 0 }

if not ($args | any { $in | str starts-with '--allow-' }) {
    $args ++= ['--allow-all']
}

let cmd = [
    /usr/local/bin/surreal
    start ...$args
    ($env.SURREAL_STORE? | default rocksdb):///var/lib/surrealdb
]
| str join " "

tasks spawn {
    tag: surreal
    msg: 'Starting SurrealDB.'
    cmd: $cmd
}
