export def sync [prefix cfg tags act] {
    let version = hub get-version $cfg
    let tag = ($prefix)_($version)
    if ($tag not-in $tags) {
        do $act { version: $version, tag: $tag }
    } else {
        trace o $tag exists
    }
    return $tag
}
