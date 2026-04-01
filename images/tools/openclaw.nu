use ../../bx *


export def main [context: record = {}] {
    {
        from: $'($context.image):playwright'
        workdir: /app/data
    }
    | merge $context
    | merge { tag: openclaw }
    | upsert skills {|x|
        $x.skills?
        | default []
        | append [
            self-improving #proactive-agent
            ontology
            file-search
            multi-search-engine
            scheduler
            playwright
            github
            ahrefs
        ]
        | uniq
    }
    | upsert plugins {|x|
        $x.plugins?
        | default []
        | append [
        ]
        | uniq
    }
    | build {|ctx|
        conf env {
            NODE_LLAMA_CPP_SKIP_DOWNLOAD: 'true'
            OPENCLAW_ALLOW_INSECURE_PRIVATE_WS: '1'
            OPENCLAW_HOME: $ctx.workdir
            OPENCLAW_CONFIG_PATH: ($ctx.workdir | path join openclaw.json)
            OPENCLAW_SKILLS: ($ctx.skills | str join ',')
        }

        pkg pip install [html2txt]

        let skills_ins = $ctx.skills | each {|x| $'clawhub install ($x)' }

        let plugins_ins = $ctx.plugins | each {|x| $'openclaw plugins install @openclaw/($x)' }

        let npm_pkgs = [
            node-html-parser
        ]
        | str join ' '

        run [
            'mkdir -p /app/data'
            'cd /app'
            # 'npm install --no-cache --omit=optional openclaw'
            $'npm install -g --no-cache openclaw clawhub ($npm_pkgs)'
            'rm -rf /usr/lib/node_modules/@node-llama-cpp node_modules/node-llama-cpp'
            ...$plugins_ins
            ...$skills_ins
        ]

        conf workdir $ctx.workdir
        copy images/tools/entrypoint/openclaw.nu /entrypoint/openclaw.nu

        conf expose [18789]
        conf cmd ['srv']
    }
}
