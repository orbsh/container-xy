#!/usr/bin/env nu
use libs/tasks.nu

if ($env.OPENFANG_API_KEY? | is-empty) and ($env.API_KEY? | is-empty) {
    print 'Please set OPENFANG_API_KEY or API_KEY environment variable'
    return
}

let conf = $env.HOME | path join .openfang/config.toml

if not ($conf | path exists) {
    openfang onboard
}

mut cfg = open $conf

$cfg.default_provider = $env.DEFAULT_PROVIDER? | default 'custom:https://dashscope.aliyuncs.com/compatible-mode/v1'
$cfg.default_model = $env.DEFAULT_MODEL? | default 'qwen3.5-122b-a10b'

$cfg.gateway.allow_public_bind = true
$cfg.gateway.host = '0.0.0.0'
$cfg.gateway.port = $env.GATEWAY_PORT? | default '42617' | into int

$cfg.browser = {
    enable: true
    allowed_domains: ["*"]
    backend: "agent_browser"
    native_headless: true
    native_webdriver_url: "http://127.0.0.1:9222"
}

if ($env.NOSTR_KEY? | is-not-empty) {
    mut c = {
        private_key: $env.NOSTR_KEY
    }
    if ($env.NOSTR_RELAY? | is-not-empty) {
        $c.relays = $env.NOSTR_RELAY | split row ','
    }
    if ($env.ALLOWED_PUBKEYS? | is-not-empty) {
        $c.allowed_pubkeys = $env.ALLOWED_PUBKEYS | split row ','
    }
    $cfg.channels_config.nostr = $c
}

if ($env.MATTERMOST_URL? | is-not-empty) {
    $cfg.channels_config.mattermost = {
        url: $env.MATTERMOST_URL
        bot_token: $env.MATTERMOST_BOT_TOKEN
        channel_id: $env.MATTERMOST_CHANNEL_ID
        allowed_users: ["*"]
        mention_only: false
        group_reply: {
            mode: "all_messages" # optional: all_messages | mention_only
            allowed_sender_ids: []
        }
    }
}

if ($env.DINGTALK_CLIENT_ID? | is-not-empty) {
    $cfg.channels_config.dingtalk = {
        client_id: $env.DINGTALK_CLIENT_ID
        client_secret: $env.DINGTALK_CLIENT_SECRET
        allowed_users: ($env.DINGTALK_ALLOWED_USERS? | split row ',' | default ["*"])
    }
}



$cfg | to toml | save -f $conf


tasks spawn {
    tag: openfang
    cmd: 'openfang gateway'
}
