export def resolve-stack [col stack pkgs] {
    let sets = open ($env.BX_DATADIR | path join hub.yaml) | get ($col | into cell-path)
    if ($stack | is-not-empty) {
        $sets
        | columns
        | do {
            let c = $in
            if 'all' in $stack { $c } else { $c | where {|x| $x in $stack } }
        }
        | each {|n| $sets | get $n}
        | flatten
    } else {
        []
    }
    | append $pkgs
    | uniq
}

export def relative-path [path] {
    $path | path split | where $it != '/' | path join
}

export def into-tree [target: path, --cwd(-c): path]: list<string> -> nothing  {
    let n = $in
    let target = $target | path expand
    mkdir $target
    if ($cwd | is-not-empty) {
        cd $cwd
    }
    for x in $n {
        let d = $target | path join ($x | path parse | get parent)
        if not ($d | path exists) {
            mkdir $d
        }
        cp -v -r $x $d
    }
}
