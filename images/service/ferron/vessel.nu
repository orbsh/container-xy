#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    let n = $in
    if ($env.REQUEST_URI | str ends-with '/') {
        content -p
        let pkgs = $env.PATH_INFO | path split | last | split row ','
        let r = $"
        for i in ($pkgs) {
            install $i /usr/local
        }
        "
        | str trim
        | str replace -rma '^ {8}' ''
        [
            (view source tar-ls)
            (view source install)
            $r
        ]
        | str join (char newline)
        | print $in
    } else if ($env.PATH_INFO | str starts-with '/vessel/install') {
        content -p
        let base = $env.PATH_INFO | path split | get 1
        $"
        if ! command -v nu >/dev/null 2>&1; then
            echo \"nu not found. Installing...\"
            curl -SL --progress-bar ($env.HTTP_HOST)/($base)/download/nushell.tar.zst | zstd -d | tar -xf - -C /usr/local
        fi
        curl -sSL ($env.HTTP_HOST)($env.PATH_INFO)/ | nu -c -
        "
        | str trim
        | str replace -rma '^ {8}' ''
        | print $in
    } else if ($env.PATH_INFO | str starts-with '/vessel/download') {
        let file = $env.PATH_INFO | path split | last
        send-file ('/opt/vessel' | path join $file)
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
