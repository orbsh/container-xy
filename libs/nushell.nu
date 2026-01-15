use utils.nu *
use trace.nu
use github.nu

export def setup [dir config: record --skip-download] {
    if not $skip_download {
        with-mount {
            let dst = relative-path $dir | path expand
            trace o -p 'install-nushell' $dst
            let plugin = $config.plugin | each {|x| $"nu_plugin_($x)" }
            github install nushell -t $dst -u {|x|
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
    }

    let reg = $config.plugin
    | each {|x| $"plugin add ($dir | path join nu_plugin_($x))"}
    | str join '; '
    run [
        $'usermod -s ($dir | path join "nu") ($config.user)'
        $'git clone --depth=3 ($config.src) ($config.dst)/nushell'
        'opwd=$PWD'
        $'cd ($config.dst)/nushell'
        'git log -1 --date=iso'
        'cd $opwd'
        $'chown ($config.user):($config.user) -R ($config.dst)/nushell'
        $'sudo -u ($config.user) nu -c "($reg)"'
        $"echo '$env.NU_POWER_CONFIG.theme.color.normal = \"xterm_olive\"' >> /home/($config.user)/.nu"
        $"chown ($config.user):($config.user) /home/($config.user)/.nu"
    ]
}
