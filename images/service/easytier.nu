use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):deb'
        user: master
        workdir: /srv
        tag: easytier
    }
    | merge $context
    | build {|ctx|
        pkg install [iptables iproute2]
        hub install [easytier] -c $ctx.cache?

        b conf expose [11010 u11010]

        b with-mount {
            r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            let secret = $env.NETWORK_SECRET?
            if ($secret | is-empty) {
                error make { msg: "NETWORK_SECRET environment variable is required" }
            }

            let is_central = ($env.IS_CENTRAL? | default "false") == "true"
            let network_name = $env.NETWORK_NAME? | default "my_mesh_net"
            let node_name = if $is_central {
                $env.NODE_NAME? | default "Central-Server"
            } else {
                $env.NODE_NAME? | default "Client-Node"
            }

            mut cmd = [
                /usr/local/bin/easytier-core
                --hostname $node_name
                --network-name $network_name
                --network-secret $secret
                --rpc-portal "127.0.0.1:15888"
            ]

            if $is_central {
                print $"🚀 Starting EasyTier [Central Server]..."
                let external = $env.EXTERNAL_IP_PORT?
                if ($external | is-not-empty) {
                    $cmd ++= [--external-node $external]
                }
                $cmd ++= [
                    --listeners "tcp://0.0.0.0:11010"
                    --listeners "udp://0.0.0.0:11010"
                ]
            } else {
                print $"📱 Starting EasyTier [Client Node]..."
                let peer_url = $env.PEER_URL?
                if ($peer_url | is-empty) {
                    error make { msg: "PEER_URL is required for client nodes (e.g., tcp://SERVER_IP:11010)" }
                }
                $cmd ++= [--peers $peer_url]
            }

            tasks spawn {
                tag: easytier
                msg: ($cmd | str join " ")
                cmd: $cmd
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save entrypoint/easytier.nu
        }

        b conf workdir $ctx.workdir
        b conf cmd ['srv']
    }
}
