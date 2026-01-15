export def run [list] {
    let n = $in
    $list
    | reduce -f $n {|x, acc|
        let r = $x | transpose k v | first
        dispatch $acc $r.k $r.v
    }
}

def dispatch [input act args?] {
    match $act {
        from-json => {
            $input | from json
        }
        prefix => {
            $"($args)($input)"
        }
        index => {
            let p = $args | split row '.' | into cell-path
            let r = do -i { $input | get $p }
            if ($r | is-empty) {
                error make { msg: $"'($args)' not in ($input)" }
            } else {
                $r
            }
        }
        field => {
            if ($args | is-empty) {
                $input
            } else {
                if $args in $input {
                    $input | get $args
                } else {
                    null
                }
            }
        }
        trim => {
            $input | str trim
        }
        substr => {
            let s = $args.0? | default '0' | into int
            let e = $args.1? | default '-1' | into int
            $input | str substring $s..$e
        }
        regexp => {
            $input | parse -r $args | get 0?.capture0?
        }
        only-nums => {
            $input | parse -r '(?P<v>[0-9\.\-]+)' | get 0?.v?
        }
        _ => {
            error make {
                msg: $"transformer `($act)` not found"
            }
        }
    }
}
