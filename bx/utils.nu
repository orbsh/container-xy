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
