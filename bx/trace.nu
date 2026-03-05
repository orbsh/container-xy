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

export def --env inc-level [] {
    $env.TRACE_LEVEL = ($env.TRACE_LEVEL? | default (-1) | into int) + 1
}

export def o [
    ...msg: any
    --prefix(-p): string
    # --lv(-l): int = 0
    --total: int = 8
] {
    let msg = parse_msg $msg

    let lv = $env.TRACE_LEVEL? | default 0 | into int
    let lv = $total - $lv
    let lv = if $lv >= 0 { $lv } else { 0 }
    let lv = '' | fill -c '*' -w $lv | fill -c ' ' -w $total -a right

    mut r = [$"(ansi grey)($lv)│($msg.time)"]
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

export def f [...prefix]: any -> any {
    let n = $in
    o -p ($prefix | str join '-') $n
    $n
}
