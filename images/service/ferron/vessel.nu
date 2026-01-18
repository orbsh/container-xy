#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    let n = $in
    let path = $env.PATH_INFO | str downcase | path split | slice 1..
    match $path {
        [vessel install $pkgs] => {
            content -p
            let r = $"
            for i in ($pkgs | split row ',') {
                print $'install \($i\)...'
                install $'($env.HTTP_HOST)/vessel/download/\($i\).tar.zst' /usr/local
            }
            "
            | str trim
            | str replace -rma '^ {12}' ''
            [
                (view source tar-fs)
                (view source install)
                $r
            ]
            | str join (char newline)
            | print $in
        }
        [vessel download $pkg] => {
            let f = '/opt/vessel' | path join $pkg
            send-file $f
        }
        [vessel $args] => {
            content -p
            let invalid = $args | split row ',' | where {|it|
                '/opt/vessel' | path join $"($it).tar.zst" | path exists | not $in
            }
            if ($invalid | is-not-empty) {
                cd /opt/vessel
                let pkgs = ls *.tar.zst
                | get name
                | each { $in | split row '.' | first }
                {
                    invalid: $invalid
                    allowed: $pkgs
                }
                | to yaml
                | print $in
                return
            }
            $"
            if ! command -v nu >/dev/null 2>&1; then
                echo \"nu not found. installing...\"
                curl -SL --progress-bar ($env.HTTP_HOST)/vessel/download/nushell.tar.zst | zstd -d | tar -xf - -C /usr/local
            fi
            curl -SL --progress-bar ($env.HTTP_HOST)/vessel/install/($args) > /tmp/vessel-install
            /usr/local/bin/nu /tmp/vessel-install
            "
            | str trim
            | str replace -rma '^ {12}' ''
            | print $in
        }
        _ => {
            content -p
            print $path
        }
    }
}

def tar-fs [f] {
    tar -tf $f
    | lines
    | reduce -f {} {|i,a|
        $a | upsert ($i | path split | first) true
    }
    | columns
}

def install [url loc] {
    let file = $url | path split | last
    let file = '/tmp' | path join $file
    curl -SL --progress-bar $url -o $file
    let fs = tar-fs $file
    cat $file | zstd -d | tar -xf - ...($fs | where $it not-in [config setup.nu]) -C $loc
    if 'config' in $fs {
        cat $file
        | zstd -d
        | tar -xf - --strip-component=1 config -C (
            $env.HOME | path join '.config'
        )
    }
    if 'setup.nu' in $fs {
        cd
        cat $file
        | zstd -d
        | tar -Oxf -
        | nu -c $in
    }
}
