export def --env init-history [] {
    $env.BUILDAH_WORKING_HISTORY = mktemp -t --suffix history
}

export def --env add-history [msg --total=8] {
    let lv = $env.TRACE_LEVEL? | default 0 | into int
    let lv = $total - $lv
    let lv = if $lv >= 0 { $lv } else { 0 }
    let lv = '' | fill -c '*' -w $lv | fill -c ' ' -w $total -a right
    {t: (date now), lv: $lv, msg: $msg} | to json -r | ($in)(char newline) | save -a $env.BUILDAH_WORKING_HISTORY
}

export def --env consume-history [] {
    let c = open -r $env.BUILDAH_WORKING_HISTORY | from json -o
    rm -f $env.BUILDAH_WORKING_HISTORY
    let msg = $c | sort-by t | each {|x| $"($x.lv) ($x.msg)" } | str join (char newline)
    print '--------'
    print $msg
    print '--------'
    $msg
}
