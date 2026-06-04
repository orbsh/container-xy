#!/usr/bin/env nu
use libs/tasks.nu

$env
| transpose k v
| each {|r|
    match ($r.k | split row '_') {
        ['tcp' $port] => {
            {
                proto: 'tcp'
                port: $port
                target: $r.v
                listen_opts: [reuseaddr fork so-keepalive=1 tcp-keepidle=30 tcp-keepintvl=10 tcp-keepcnt=6]
                connect_opts: [so-keepalive=1 tcp-keepidle=30 tcp-keepintvl=10 tcp-keepcnt=6]
            }
        }
        ['udp' $port] => {
            {
                proto: 'udp'
                port: $port
                target: $r.v
                listen_opts: [pf=ip4 reuseaddr fork]
                connect_opts: []
            }
        }
    }
}
| each {|j|
    let connect = [($j.proto):($j.target), ...$j.connect_opts] | str join ','
    let listen = [($j.proto)-listen:($j.port), ...$j.listen_opts] | str join ','
    {
        tag: $"socat_($j.proto)_($j.port)"
        msg: $"($j.proto):($j.port) --> ($j.target)"
        cmd: [ sudo socat $listen $connect ]
    }
}
| tasks spawn ...$in
