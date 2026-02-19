
export def tags [repo] {
    let token = curl -sL $'https://ghcr.io/token?service=ghcr.io&scope=repository:($repo):pull'
    | from json | get token
    curl -sL -H $"Authorization: Bearer ($token)" $"https://ghcr.io/v2/($repo)/tags/list"
    | from json | get tags
}
