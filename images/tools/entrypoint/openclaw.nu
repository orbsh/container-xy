#!/usr/bin/env nu
use libs/tasks.nu
use libs/info.nu

const SKILL_DIR = '/app/skills'

def setup-models [] {
    mut cfg = {
        models: {
            providers: {}
        }
        agents: {
            defaults: {
                models: {}
            }
        }
    }
    let e = $env
    | transpose k v
    | reduce -f [] {|i, a|
        let r = $i.k | parse -r '^(?<m>.+)_API_KEY$'
        if ($r | is-not-empty) {
            let id =  $r.0.m
            let name = $id | str downcase
            $a | append {
                id: $id
                name: $name
                key: $i.k
                value: $i.v
            }
        } else {
            $a
        }
    }

    for i in $e {
        let models = $env
        | get -o ($i.id)_MODEL
        | default (match $i.name {
            qwen => 'qwen3.5-122b-a10b'
            glm => 'glm-4.7'
        })
        | split row ','
        | each {|x|
            {
                id: $x
                name: $"($x) \(Custom Provider\)"
                reasoning: false
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
        }

        let baseUrl = $env
        | get -o ($i.id)_BASE_URL
        | default (match $i.name {
            qwen => "https://dashscope.aliyuncs.com/compatible-mode/v1"
            glm => "https://open.bigmodel.cn/api/paas/v4"
        })

        $cfg.models.providers = $cfg.models.providers
        | insert $i.name {
            baseUrl: $baseUrl
            apiKey: {
                source: env
                provider: default
                id: $i.key
            }
            api: openai-completions
            models: $models
        }

        if ($cfg.agents.defaults.model? | is-empty) {
            $cfg.agents.defaults.model = {
                primary: $"($i.name)/($models.0.id)"
            }
        }

        for x in $models {
            $cfg.agents.defaults.models = $cfg.agents.defaults.models
            | insert $"($i.name)/($x.id)" {
                alias: $"($i.name)/($x.id)"
            }
        }

    }
    return $cfg
}

def fetch-skills [] {
    mut config = {}
    for url in ($env.SKILL_PACKAGE_URLS | split row ',') {
        let w = mktemp -d
        if ($env.SKILL_PACKAGE_AUTH? | is-not-empty) {
            let up = ($env.SKILL_PACKAGE_AUTH | split row ':' | first 2)
            http get -r --user $up.0 --password $up.1 $url
        } else {
            http get -r $url
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

def gen-config [file home] {
    mkdir $home

    let token = random binary 24 | encode hex | str downcase

    mut skill_entries = $env.OPENCLAW_SKILLS
    | split row ','
    | reduce -f {} {|i, a|
        $a | upsert $i { enabled: true }
    }

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
        profile: coding
      },
      commands: {
        native: auto,
        nativeSkills: auto,
        restart: true,
        ownerDisplay: raw
      },
      skills: {
        load: {
          extraDirs: [$SKILL_DIR]
        },
        entries: $skill_entries
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
      },
      plugins: {
        entries: {
          qwen-portal-auth: {
            enabled: true
          }
        }
      }
    }

    $cfg
    | merge deep --strategy=append (setup-models)
    | to json
    | save -f $file
    $token
}


def update-nu-config [] {
    let tmpl = r#'

    def cmpl-reqid [] {{
        openclaw devices list --json
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
        openclaw devices approve $req_id
    }}
    '#

    { } | format pattern $tmpl | save -a ($env.HOME | path join .config/nushell/config.nu)
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

if ($env.OPENCLAW_GATEWAY_TOKEN? | is-empty) {
    let token = if not ($env.OPENCLAW_CONFIG_PATH | path exists) {
        update-nu-config
        gen-config $env.OPENCLAW_CONFIG_PATH $env.OPENCLAW_HOME
    } else {
        open $env.OPENCLAW_CONFIG_PATH | get gateway.auth.token
    }
    info $"gateway_token ($token)"


    if ($env.SKILL_PACKAGE_URLS? | is-not-empty) {
        open $env.OPENCLAW_CONFIG_PATH
        | update skills.entries {|x|
            $x.skills.entries | merge (fetch-skills)
        }
    }


    tasks spawn {
        tag: openclaw
        cmd: 'openclaw gateway'
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
        cmd: $"openclaw node run ($args | str join ' ')"
        polling_interval: 5sec
    }
}
