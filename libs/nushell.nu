use b.nu
use trace.nu
use hub.nu
const CFG = path self ../hub.yaml

export def setup [
    dir
    config: record
    --skip-download
    --cache(-c): string = ''
] {
    trace inc-level

    if not $skip_download {
        trace o -p 'install-nushell' $dir
        hub install [nushell] -t $dir -c $cache -o {|x|
            $x | upsert plugins $config.plugins
        }
    }

    let install_path = $dir | path join bin "nu"
    b run [
        $"echo '($install_path)' >> /etc/shells"
        $'usermod -s ($install_path) ($config.user)'
    ]

    let custom_conf = if $config.user == 'root' {
        'root/.nu'
    } else {
        $'home/($config.user)/.nu'
    }
    b with-mount {
        let cfg = (open $CFG).settings.nushell
        let xdg_config = relative-path $config.xdg_config
        | path expand
        | path join nushell

        if ($xdg_config | path exists) {
            rm -rf $xdg_config
        }
        git clone --depth=($cfg.clone?.depth? | default 3) $cfg.git $xdg_config

        [
            '$env.NU_POWER_CONFIG.theme.color.normal = "xterm_olive"'
            'export alias pst = pueue status'
            'export alias pf = pueue follow'
        ]
        | str join (char newline)
        | save -a $custom_conf

        cd $xdg_config
        git log -1 --date=iso
    }

    let reg = $config.plugins
    | each {|x| $"plugin add ($dir | path join bin nu_plugin_($x))"}
    | str join '; '

    b run [
        $"chown ($config.user):($config.user) /($custom_conf)"
        $'chown ($config.user):($config.user) -R ($config.xdg_config)/nushell'
        $'sudo -u ($config.user) nu -c "($reg)"'
    ]
}
