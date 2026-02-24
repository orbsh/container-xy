use ../../libs *

export def main [context: record = {}] {
    {
        from: 'archlinux'
        author: unnamed
        timezone: Asia/Shanghai
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        conf expose [22]
        conf env {
            LANG: C.UTF-8
            LC_ALL: C.UTF-8
            TIMEZONE: $ctx.timezone
            MASTER: $ctx.user
            PYTHONUNBUFFERED: x
        }
        pkg update
        pkg install [
            sudo cronie tzdata
            # base-devel
            # nushell
            git
            openssh rsync dropbear s3fs
            strace tcpdump socat websocat
            ripgrep dust
            tree
        ]
        setup timezone $ctx.timezone
        setup sudo

        setup git $ctx.author
        let xdg_config = $"/home/($ctx.user)/.config"
        setup master $ctx.user $ctx.workdir $xdg_config

        nushell setup '/usr/local' {
            user: $ctx.user
            xdg_config: $xdg_config
            plugins: [query]
        }

        hub install --user $ctx.user -A $ctx.author [
            duckdb
        ]

        pkg setup python [
            ty
            httpx aiofile aiostream fastapi uvicorn
            debugpy pytest pydantic pydantic-graph PyParsing
            typer pydantic-settings pyyaml
            boltons decorator
        ]
        pkg setup js [
            @typespec/compiler @typespec/json-schema
            vscode-langservers-extracted
            yaml-language-server
        ]

        # conf volume [$ctx.workdir]
        conf env {
            DEBUGE: ''
            PREBOOT: ''
            POSTBOOT: ''
            CRONFILE: ''
        }
        conf workdir $ctx.workdir
        conf cmd []
        copy entrypoint /entrypoint
        conf entrypoint ["/entrypoint/libs/init.nu"]
    }
}
