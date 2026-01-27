#!/usr/bin/env nu
use init.nu [pueue-extend now]

let b = $env.HOME | path join '.config' 'zellij'
let keyfile = $b | path join zellij-key.pem
let certfile = $b | path join zellij-cert.pem

if ($env.ZELLIJ | is-not-empty) {
    mkcert -install
    mkcert -key-file $keyfile -cert-file $certfile localhost 127.0.0.1 0.0.0.0
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

    let g = 'default'
    pueue-extend $g
    pueue add -g $g -l zellij-web -- zellij web
}
