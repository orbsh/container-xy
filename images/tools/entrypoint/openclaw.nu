#!/usr/bin/env nu
use libs/tasks.nu
use libs/info.nu

def init [file home] {
    mkdir $home

    let token = random binary 24 | encode hex | str downcase

    mut cfg = {
      models: {
        mode: merge,
        providers: {}
      },
      agents: {
        defaults: {
          workspace: $home,
          compaction: {
            mode: safeguard
          }
        }
      },
      tools: {
        profile: coding,
        web: {
          search: {
            provider: kimi
          }
        }
      },
      commands: {
        native: auto,
        nativeSkills: auto,
        restart: true,
        ownerDisplay: raw
      },
      session: {
        dmScope: per-channel-peer
      },
      gateway: {
        port: 18789,
        mode: local,
        bind: lan,
        controlUi: {
          allowedOrigins: [ "http://localhost:18789", "http://127.0.0.1:18789" ]
        },
        auth: {
          mode: token,
          token: $token
        },
        tailscale: {
          mode: off,
          resetOnExit: false
        },
        nodes: {
          denyCommands: [ "camera.snap", "camera.clip", "screen.record", "contacts.add", "calendar.add", "reminders.add", "sms.send" ]
        }
      }
    }

    if ($env.QWEN_API_KEY? | is-not-empty) {
        let model = $env.QWEN_MODEL? | default 'qwen3.5-122b-a10b'
        $cfg.models.providers.custom-dashscope-aliyuncs-com = {
          baseUrl: "https://dashscope.aliyuncs.com/compatible-mode/v1",
          apiKey: {
            source: env,
            provider: default,
            id: QWEN_API_KEY
          },
          api: openai-completions,
          models: [
            {
                id: $model
                name: $"($model) \(Custom Provider\)"
                reasoning:false
                input: [text]
                cost:{
                  input: 0
                  output: 0
                  cacheRead: 0
                  cacheWrite: 0
                }
                contextWindow: 16000
                maxTokens: 4096
            }
          ]
        }
        $cfg.agents.defaults.model = {
          primary: $"custom-dashscope-aliyuncs-com/($model)"
        }
        $cfg.agents.defaults.models = {
          $"custom-dashscope-aliyuncs-com/($model)": {
            alias: "qwen3.5"
          }
        }
    }

    $cfg | to json | save -f $file
    $token
}

let bin = '/app' | path join node_modules .bin openclaw

let tmpl = r#'

def cmpl-reqid [] {{
    {bin} devices list --json
    | from json
    | get pending
    | each {{|x|
        {{
            value: $x.requestId
            descriptioin: $"($x.deviceId | str substring ..6)|($x.clientId)|($x.clientMode)"
        }}
    }}
}}

export def openclaw-devices-approve [req_id: string@cmpl-reqid] {{
    {bin} devices approve $req_id
}}
'#

{ bin: $bin } | format pattern $tmpl | save -a ($env.HOME | path join .config/nushell/config.nu)

if ($env.OPENCLAW_GATEWAY_TOKEN? | is-empty) {
    if not ($env.OPENCLAW_CONFIG_PATH | path exists) {
        let token = init $env.OPENCLAW_CONFIG_PATH $env.OPENCLAW_HOME
        info $"gateway_token ($token)"
    }

    tasks spawn {
        tag: openclaw
        cmd: $'($bin) gateway'
    }
} else {
    let port = $env.OPENCLAW_GATEWAY_PORT? | default '18789'
    mut args = [
        --host $env.OPENCLAW_GATEWAY_HOST --port $port
    ]
    if ($env.OPENCLAW_NODE_ID? | is-not-empty) {
        $args ++= [--node-id $env.OPENCLAW_NODE_ID]
    }
    tasks spawn {
        tag: openclaw-node
        cmd: $"($bin) node run ($args | str join ' ')"
        polling_interval: 5sec
    }
}
