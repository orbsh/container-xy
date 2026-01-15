use utils.nu *
use lg.nu

export def setup [user dir config: record --skip-download] {
    if not $skip_download {
        let ver = curl --retry 3 -fsSL https://api.github.com/repos/nushell/nushell/releases/latest | from json | get tag_name
        lg o -p 'nushell-version' $ver

        let url = $"https://github.com/nushell/nushell/releases/download/($ver)/nu-($ver)-x86_64-unknown-linux-musl.tar.gz"

        with-mount {
            let dst = relative-path $dir | path expand
            lg o -p 'nushell-dir' $dst
            let plugin = $config.plugin | each {|x| $"*/nu_plugin_($x)" }
                curl --retry 3 -fsSL $url | tar -zxf - -C $dst --strip-components=1 --wildcards '*/nu' ...$plugin
        }
    }

    let reg = $config.plugin
    | each {|x| $"plugin add ($dir | path join nu_plugin_($x))"}
    | str join '; '
    run [
        $'usermod -s ($dir | path join "nu") ($user)'
        $'git clone --depth=3 ($config.src) ($config.dst)/nushell'
        'opwd=$PWD'
        $'cd ($config.dst)/nushell'
        'git log -1 --date=iso'
        'cd $opwd'
        $'chown ($user):($user) -R ($config.dst)/nushell'
        $'sudo -u ($user) nu -c "($reg)"'
        $"echo '$env.NU_POWER_CONFIG.theme.color.normal = \"xterm_olive\"' >> /home/($user)/.nu"
        $"chown ($user):($user) /home/($user)/.nu"
    ]
}
