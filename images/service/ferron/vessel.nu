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
                install ($env.HTTP_HOST)/vessel/download/$i /usr/local
            }
            "
            | str trim
            | str replace -rma '^ {12}' ''
            [
                (view source tar-ls)
                (view source install)
                $r
            ]
            | str join (char newline)
            | print $in
        }
        [vessel download $pkg] => {
            let f = '/opt/vessel' | path join $pkg | $"($in).tar.zst"
            send-file $f
        }
        [vessel $args] => {
            content -p
            let ne = $args | split row ',' | where {|it|
                '/opt/vessel' | path join $"($it).tar.zst" | path exists | not $in
            }
            if ($ne | is-not-empty) {
                print $"pkgs not exists: [($ne | str join ', ')]"
                return
            }
            $"
            if ! command -v nu >/dev/null 2>&1; then
                echo \"nu not found. Installing...\"
                curl -SL --progress-bar ($env.HTTP_HOST)/vessel/download/nushell.tar.zst | zstd -d | tar -xf - -C /usr/local
            fi
            curl -sSL ($env.HTTP_HOST)/vessel/install/($args) | nu -c -
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

def tar-ls [f] {
    tar -tf $f
    | lines
    | reduce -f {} {|i,a|
        $a | upsert ($i | path split | first) true
    }
    | columns
}

def install [url loc] {
    curl -SL --progress-bar $url | zstd -d | tar -xf - -C $loc
}
