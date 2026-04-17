#!/usr/bin/env nu
use libs/tasks.nu
use libs/info.nu

const SKILL_DIR = '/app/data/skills'

def fetch-skills [] {
    mut config = {}
    for url in ($env.SKILL_PACKAGE_URLS | split row ',') {
        let w = mktemp -d
        if ($env.SKILL_PACKAGE_AUTH? | is-not-empty) {
            curl -sSL -u $env.SKILL_PACKAGE_AUTH $url
        } else {
            curl -sSL $url
        }
        | zstd -d
        | tar xf - -C $w
        cd $w
        let cfg = open config.yaml
        rm config.yaml
        let name = $cfg.name
        $config = $config | upsert $name ($cfg | reject name)
        cd $SKILL_DIR
        mv $w $name
        info setup-skill {name: $name, url: $url}
    }
    $config
}

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
    cmd: $"hermes gateway"
    polling_interval: 5sec
}
