#!/usr/bin/env nu
use libs/tasks.nu


mkdir $env.OPENCLAW_HOME
let conf = $env.OPENCLAW_HOME | path join openclaw.json
let token = random binary 24 | encode hex | str downcase

if not ($conf | path exists) {
    mut cfg = {
      models: {
        mode: merge,
        providers: {
          custom-dashscope-aliyuncs-com: {
            baseUrl: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            apiKey: {
              source: env,
              provider: default,
              id: OPENAI_API_KEY
            },
            api: openai-completions,
            models: [
              [ id, name, reasoning, input, cost, contextWindow, maxTokens ];
              [
                "qwen3.5-122b-a10b",
                "qwen3.5-122b-a10b (Custom Provider)",
                false,
                [ text ],
                {
                  input: 0,
                  output: 0,
                  cacheRead: 0,
                  cacheWrite: 0
                },
                16000,
                4096
              ]
            ]
          }
        }
      },
      agents: {
        defaults: {
          model: {
            primary: "custom-dashscope-aliyuncs-com/qwen3.5-122b-a10b"
          },
          models: {
            "custom-dashscope-aliyuncs-com/qwen3.5-122b-a10b": {
              alias: "qwen3.5"
            }
          },
          workspace: $env.OPENCLAW_HOME,
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
    $cfg | to json | save -f $conf
}

let bin = $env.OPENCLAW_HOME | path join node_modules .bin openclaw

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

{bin: $bin} | format pattern $tmpl | save -a ($env.HOME | path join .config/nushell/config.nu)

tasks spawn {
    tag: openclaw
    cmd: $'($bin) gateway'
}
