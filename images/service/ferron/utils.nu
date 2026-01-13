export def json [...acts] {
    print "Content-Type: application/json\n"
    for a in $acts {
        let x = do $a
        if ($x | is-not-empty) {
            return ($x | to json -r)
        }
    }
}

export def route [
    pattern
    act
    --method(-m): string
] {
    if ($method | is-not-empty) {
        if ($env.REQUEST_METHOD | str downcase) != ($method | str downcase) {
            return
        }
    }
    let d = $env.PATH_INFO | parse -r $pattern
    if ($d | is-not-empty) {
        do $act ($d | first)
    }
}

export def query [] {
    $env.QUERY_STRING? | default '' | url split-query
}

export def info [] {
    $env
    | transpose k v
    | where {|x|
        $x.k =~ '^(HTTP|PATH|QUERY|REMOTE|REQUEST|SCRIPT|SERVER|CONTENT|GATEWAY|DOCUMENT)_'
    }
    | reduce -f {} {|i, a|
        $a | insert $i.k $i.v
    }
}
