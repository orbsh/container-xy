#!/usr/bin/env nu
use libs/tasks.nu

mut args = $env.SURREAL_ARGV? | default '' | split row ','

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
