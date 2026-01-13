#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    let n = $in
    let p = $env.PATH_INFO
    if ($p | str starts-with '/inspect') {
        content -j
        $n
        | info
        | to json -r
    } else if ($p | str starts-with '/log') {
        log ($n | info)
    } else if ($p | str starts-with '/status-code') {
    } else if ($p | str starts-with '/redirect') {
    } else {
        content -j
        { hello: 'world' }
        | to json -r
    }
}

def log [data] {
    match ($env.REQUEST_METHOD | str downcase) {
        post => {
            content -p
            let t = date now | format date "%+"
            let f = path-to-file | path join $t
            let p = $f | path parse | get parent
            if not ($p | path exists) { mkdir $p }
            $data | to yaml | save -f $f
            let uri = $env.PATH_INFO | path join $t
            let url = ($env.HTTP_HOST)($uri)
            return $url
        }
        _ => {
            send-file (path-to-file)
        }
    }
}

def info [] {
    let n = $in
    let q = $env.QUERY_STRING? | default '' | url split-query
    let h = $env
    | transpose k v
    | reduce -f {} {|i,a|
        if ($i.k | str starts-with 'HTTP_') {
            $a | insert ($i.k | str substring 5..) $i.v
        } else {
            $a
        }
    }
    let is_b = $n | into binary | is-binary-file
    let b = if $is_b {
        $n | encode base64
    } else {
        let r = do -i { $n | from json }
        if ($r | is-empty) {
            $n
        } else {
            $r
        }
    }
    {
        remote: {
            addr: $env.REMOTE_ADDR
            port: $env.REMOTE_PORT
        }
        server: {
            addr: $env.SERVER_ADDR
            name: $env.SERVER_NAME
            port: $env.SERVER_PORT
        }
        proto: $env.SERVER_PROTOCOL
        method: $env.REQUEST_METHOD
        path: $env.PATH_INFO
        uri: $env.REQUEST_URI
        query: $q
        headers: $h
        body: $b
    }
}
