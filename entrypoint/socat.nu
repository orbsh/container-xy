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
                options: [reuseaddr fork]
            }
        }
        ['udp' $port] => {
            {
                proto: 'udp'
                port: $port
                target: $r.v
                options: [pf=ip4 reuseaddr fork]
            }
        }
    }
}
| each {|j|
    {
        tag: $"socat_($j.proto)_($j.port)"
        msg: $"($j.proto):($j.port) --> ($j.target)"
        cmd: $"sudo socat ($j.proto)-listen:($j.port),($j.options | str join ',') ($j.proto):($j.target)"
    }
}
| tasks spawn ...$in
