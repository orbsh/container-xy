#!/usr/bin/env nu
use init.nu [pueue-extend pueue-spawn now]

def cert-file []: path -> path {
    $in
    | path parse
    | update stem {
        $in | split row '-' | slice ..-2 | append cert | str join '-'
    }
    | path join
}
let b = $env.HOME | path join '.config' 'zellij'
let keyfile = $b | path join zellij-key.pem
let certfile = $keyfile | cert-file

if ($env.MKCERT? | is-not-empty) {
    mkcert -install
    let cert = $env.MKCERT | cert-file
    mkcert -key-file $env.MKCERT -cert-file $cert localhost 127.0.0.1 0.0.0.0
}

if ($keyfile | path exists) {
    $'
    web_server true
    web_server_port 2311
    web_server_ip "0.0.0.0"
    web_server_cert "($keyfile)"
    web_server_key "($certfile)"
    '
    | save -a ($b | path join 'config.kdl')

    zellij web --create-token

    'zellij web' | pueue-spawn zellij-web
}
