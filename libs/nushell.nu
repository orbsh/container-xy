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

    b with-mount {
        let cfg = (open $CFG).settings.nushell
        let dst = relative-path $config.dst
        | path expand
        | path join nushell
        git clone --depth=($cfg.clone?.depth? | default 3) $cfg.git $dst

        [
            '$env.NU_POWER_CONFIG.theme.color.normal = "xterm_olive"'
            'export alias pst = pueue status'
            'export alias pf = pueue follow'
        ]
        | str join (char newline)
        | save -a $'home/($config.user)/.nu'

        cd $dst
        git log -1 --date=iso
    }

    let reg = $config.plugins
    | each {|x| $"plugin add ($dir | path join bin nu_plugin_($x))"}
    | str join '; '

    b run [
        $"chown ($config.user):($config.user) /home/($config.user)/.nu"
        $'chown ($config.user):($config.user) -R ($config.dst)/nushell'
        $'sudo -u ($config.user) nu -c "($reg)"'
    ]
}
