#!/usr/bin/env nu
use libs/tasks.nu
use libs/info.nu

const SKILL_DIR = '/app/data/skills'

if ($env.PROXY? | is-not-empty) {
    let proxy = $env.PROXY
    $env.http_proxy = $proxy
    $env.https_proxy = $proxy
    $env.no_proxy = 'localhost,127.0.0.1'
    if ($proxy | url parse).scheme in [socks5 socks5h] {
        $env.all_proxy = $proxy
    }
}

tasks spawn {
    tag: hermes
    cmd: [hermes gateway]
    polling_interval: 5sec
}
