use utils.nu *
use trace.nu
use hub.nu
const CFG = path self ../hub.yaml

export def setup [
    dir
    config: record
    --skip-download
    --cache(-c): string = ''
] {
    let injection = [
        'export alias pst = pueue status'
        'export alias pf = pueue follow'
    ]

    if not $skip_download {
        trace o -p 'install-nushell' $dir
        let plugin = $config.plugin | each {|x| $"nu_plugin_($x)" }
        hub install [nushell] -t $dir -c $cache -u {|x|
            $x | each {|y|
                if ($y | str starts-with "filter") {
                    let f = [nu] | append $plugin | uniq
                    $"filter ($f | str join ' ')"
                } else {
                    $y
                }
            }
        }
    }

    run [
        $'usermod -s ($dir | path join bin "nu") ($config.user)'
    ]

    with-mount {
        mkdir root/.config/nushell

        [
            '$env.config.show_banner = "short"'
            ...$injection
        ]
        | str join (char newline)
        | save -a root/.config/nushell/config.nu
    }

    with-mount {
        let cfg = (open $CFG).settings.nushell
        let dst = relative-path $config.dst
        | path expand
        | path join nushell
        git clone --depth=($cfg.clone?.depth? | default 3) $cfg.git $dst

        [
            '$env.NU_POWER_CONFIG.theme.color.normal = "xterm_olive"'
            ...$injection
        ]
        | str join (char newline)
        | save -a $'home/($config.user)/.nu'

        cd $dst
        git log -1 --date=iso
    }

    let reg = $config.plugin
    | each {|x| $"plugin add ($dir | path join bin nu_plugin_($x))"}
    | str join '; '

    run [
        $"chown ($config.user):($config.user) /home/($config.user)/.nu"
        $'chown ($config.user):($config.user) -R ($config.dst)/nushell'
        $'sudo -u ($config.user) nu -c "($reg)"'
    ]
}
