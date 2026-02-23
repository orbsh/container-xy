#!/usr/bin/env nu
use init.nu [tasks]

$env
| transpose k v
| each {|r|
    match ($r.k | split row '_') {
        ['tcp' $port] => {
            {
                proto: 'tcp'
                port: $port
                target: $r.v
            }
        }
        ['udp' $port] => {
            {
                proto: 'udp'
                port: $port
                target: $r.v
            }
        }
    }
}
| each {|j|
    {
        tag: $"socat_($j.proto)_($j.port)"
        msg: $"($j.proto):($j.port) --> ($j.target)"
        cmd: $"sudo socat ($j.proto)-listen:($j.port),reuseaddr,fork ($j.proto):($j.target)"
    }
}
| tasks spawn ...$in
