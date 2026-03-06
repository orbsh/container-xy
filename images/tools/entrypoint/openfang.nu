#!/usr/bin/env nu
use libs/tasks.nu


let d = $env.HOME | path join .openfang
mkdir $d
let conf = $d | path join config.toml

if not ($conf | path exists) {
    mut cfg = {}

    $cfg.api_listen = "0.0.0.0:4200"

    if ($env.MATTERMOST_TOKEN? | is-not-empty) {
        $cfg.channels.mattermost = {
            server_url: $env.MATTERMOST_SERVER_URL
            token_env: 'MATTERMOST_TOKEN'
        }
    }

    if ($env.QWEN_API_KEY? | is-not-empty) {
        $cfg.default_model = {
            provider: 'qwen'
            model: 'qwen-max'
            api_key_env: 'QWEN_API_KEY'
        }
        $cfg.routing = {
            simple_model: 'qwen-turbo'
            medium_model: 'qwen-plus'
            complex_model: 'qwen-max'
            simple_threshold: 100
            complex_threshold: 500
        }
    }

    $cfg.memory = {
        decay_rate: 0.05
    }

    $cfg | to toml | save -f $conf
}


tasks spawn {
    tag: openfang
    cmd: 'openfang start'
}
