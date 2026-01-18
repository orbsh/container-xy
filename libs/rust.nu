use b.nu
use trace.nu

export def up [
    owner
    channel
    --component: list
    --target: list
    --bin: list
] {
    trace inc-level
    b run [
        $"rustup default ($channel)"
        $"rustup toolchain install"
    ]
    if ($component | is-not-empty) {
        b run [
            $"rustup component add ($component | str join ' ')"
        ]
        b with-mount {
            let dst = 'usr/bin' | path expand
            trace o -p 'rust-component' $dst
            for b in [rust-analyzer] {
                if ($b in $component) and not ($dst | path join $b | path exists) {
                    trace o -p 'fix-rustup-bin' $b
                    ln -sf /usr/bin/rustup ($dst | path join $b)
                }
            }
        }
    }
    if ($target | is-not-empty) {
        b run [
            $"rustup target add ($target | str join ' ')"
        ]
    }
    if ($bin | is-not-empty) {
        b with-mount {
            let dst = 'usr/local/bin/' | path expand
            trace o -p 'cargo-binstall-dir' $dst
            let url = 'https://github.com/cargo-bins/cargo-binstall/releases/latest/download/cargo-binstall-x86_64-unknown-linux-musl.tgz'
            curl -fsSL $url | tar zxf - -C $dst
            chmod +x ($dst | path join cargo-binstall)
        }
        b run [
            $"cargo binstall -y ($bin | str join ' ')"
        ]
    }
    b run [
        "rm -rf ${CARGO_HOME}/registry/src/*"
        $'chown ($owner):($owner) -R ${CARGO_HOME}'
    ]
}

export def prefetch [owner workdir proj pkgs --test --debug: string] {
    trace inc-level
    # mkdir $dst
    b run [
        $"cd ($workdir)"
        $"pwd"
        $"cargo new ($proj)"
        $"cd ($proj)"
        $"pwd"
    ]

    let pkgs = $pkgs | reduce -f {} {|i,a|
        $a | insert $i '*'
    }

    b with-mount {
        let dst = relative-path $workdir | path expand
        let dstf = $dst | path join $proj Cargo.toml
        trace o -p 'prefetch' ($dstf | path relative-to $dst)
        if ($debug | is-not-empty) {
            {
                dst: $dst
                dstf: $dstf
            }
            | load-env
            use upterm.nu
            upterm $debug
        }

        cat $dstf | from toml | update dependencies $pkgs
        | do { let n = $in; print $n; $n }
        | save -f $dstf
    }

    if $test {
        b run [$'cat ($workdir)/($proj)/Cargo.toml']
        return
    }

    b run [
        $"cd ($workdir | path join $proj)"
        "cargo fetch"
        $"cd ($workdir)"
        $"chown ($owner):($owner) -R ($proj)"
        "rm -rf ${CARGO_HOME}/registry/src/*"
        $'chown ($owner):($owner) -R ${CARGO_HOME}'
    ]
}
