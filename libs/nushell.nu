use utils.nu *
use trace.nu
use github.nu

export def setup [
    dir
    config: record
    --skip-download
    --cache(-c): string = ''
] {
    if not $skip_download {
        trace o -p 'install-nushell' $dir
        let plugin = $config.plugin | each {|x| $"nu_plugin_($x)" }
        github install [nushell] -t $dir -c $cache -u {|x|
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
        let dst = relative-path $config.dst
        | path expand
        | path join nushell
        git clone --depth=3 $config.src $dst
        cd $dst
        git log -1 --date=iso
    }

    let reg = $config.plugin
    | each {|x| $"plugin add ($dir | path join bin nu_plugin_($x))"}
    | str join '; '

    run [
        $'chown ($config.user):($config.user) -R ($config.dst)/nushell'
        $'sudo -u ($config.user) nu -c "($reg)"'
        $"echo '$env.NU_POWER_CONFIG.theme.color.normal = \"xterm_olive\"' >> /home/($config.user)/.nu"
        $"chown ($config.user):($config.user) /home/($config.user)/.nu"
    ]
}
