def file_uploaded [o] {
    $o | to yaml | print $in
    for i in 1..10 {
        sleep 1sec
        print $i
    }
}
