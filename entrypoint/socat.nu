#!/usr/bin/env nu
use init.nu [pueue-extend pueue-spawn now]

def run_socat [job] {
    if ($job | is-empty) { return }
    let g = 'default'
    pueue-extend $g ($job | length)
    for j in $job {
        $"sudo socat ($j.proto)-listen:($j.port),reuseaddr,fork ($j.proto):($j.target)"
        | pueue-spawn --unsafe $"socat_($j.proto)_($j.port)"
        print $"(now)($j.proto):($j.port) --> ($j.target)"
    }
}

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
| run_socat $in
