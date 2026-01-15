use trace.nu
use utils.nu *

export def as [
    ext file
] {
    let n = $in
    match $ext {
        [tar gz]  => {
            $n | tar zxf -
        }
        [tar zst] => {
            $n | zstd -d -T0 | tar xf -
        }
        [tar bz2] => {
            $n | tar jxf -
        }
        [tar xz]  => {
            $n | tar Jxf -
        }
        [_ gz]      => {
            $n | gzip -d | save -f $file
        }
        [_ zst]     => {
            $n | zstd -d | save -f $file
        }
        [_ bz2]     => {
            $n | bzip2 -d | save -f $file
        }
        [_ xz]      => {
            $n | xz -d | save -f $file
        }
        [_ zip]     => {
            unzip
        }
        _ => {}
    }
}

export def unpack [acts?: list = []] {
    mut dirs = []
    for a in $acts {
        let r = $a | split row -r '\s+'
        let d = dispatch $r.0 ($r | slice 1..)
        $dirs ++= [$d]
        cd $d
    }
    $dirs
}

def dispatch [act args?] {
    trace o $act $args
    match $act {
        strip => {
            let s = $args.0? | default '1' | into int
            for i in ..<$s {
                let d = ls | where type == dir | first | get name
                cd $d
            }
        }
        wrap => {
            let s = $args.0? | default 'bin'
            let t = mktemp -t -d
            let n = $t | path join $s
            glob **/* | into-tree $n
            cd $t
        }
        filter => {
            let s = $args | each { $in | into glob }
            let t = mktemp -t -d
            for x in (ls ...$s | get name) {
                let d = $t | path join ($x | path parse | get parent)
                if not ($d | path exists) {
                    mkdir $d
                }
                cp -v -r $x $d
            }
            cd $t
        }
        mv => {
            mv $args.0 $args.1
        }
        chmodx => {
            for f in $args {
                chmod +x $f
            }
        }
    }
    pwd
}
