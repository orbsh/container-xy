export def parse_msg [args] {
    let time = date now | format date '%FT%T.%3f'
    let s = $args
        | reduce -f {tag: {}, txt:[]} {|x, acc|
            if ($x | describe -d).type == 'record' {
                $acc | update tag ($acc.tag | merge $x)
            } else {
                $acc | update txt ($acc.txt | append $x)
            }
        }
    {time: $time, txt: $s.txt, tag: $s.tag }
}

export def o [...msg: any --prefix(-p): string] {
    let msg = parse_msg $msg
    mut r = [$"(ansi grey)******($msg.time)"]
    if ($prefix | is-not-empty) {
        $r ++= [$"<($prefix)>"]
    }
    if ($msg.tag? | is-not-empty) {
        let tag = $msg.tag | items {|k, v| $"($k)=($v)"} | str join ' '
        $r ++= [$tag]
    }
    if ($msg.txt? | is-not-empty) {
        $r ++= [($msg.txt | str join ' ')]
    }
    let msg = $r | str join "│"
    print $"($msg)(ansi reset)"
}

export def f [...prefix] {
    let n = $in
    o -p ($prefix | str join '-') $n
    $n
}
