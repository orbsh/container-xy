#!/usr/bin/env -S nu --stdin

export def main [] {
    let n = $in
    print "Content-Type: application/json\n"
    $env
    | transpose k v
    | where {|x|
        $x.k =~ '^(HTTP|PATH|QUERY|REMOTE|REQUEST|SCRIPT|SERVER|CONTENT|GATEWAY|DOCUMENT)_'
    }
    | reduce -f {} {|i, a|
        $a | insert $i.k $i.v
    }
    | to json
}
