use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):sid'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        hub install [
            # registry
            zot
        ]
        conf cmd [srv]
        with-mount {
            mkdir etc/zot
            {
                storage: {
                    rootDirectory: /var/lib/registry
                },
                http: {
                    address: "0.0.0.0",
                    port: "5000",
                    compat: [
                        "docker2s2"
                    ]
                },
                log: {
                    level: debug
                }
            }
            | to json
            | save -f etc/zot/config.json

            r#'
            #!/usr/bin/env nu
            use init.nu [pueue-extend now]

            def run-zot [] {
                let s3 = if ($env.S3_BACKEND? | is-empty) {
                    {}
                } else {
                    let o = $env.S3_BACKEND | from json
                    {
                        storageDriver: {
                            name: "s3",
                            regionendpoint: $s3.endpoint,
                            forcepathstyle: $s3.pathstyle?,
                            region: $s3.region,
                            bucket: $s3.bucket,
                            secure: $s3.secure,
                            skipverify: $s3.skipverify?,
                            accesskey: $s3.accessKey,
                            secretkey: $s3.secretKe"
                        },
                    }
                }

                let retention = (if $env.RETENTION_REPO? | is-empty) {
                    {}
                } else {
                    {
                        repositories: $env.RETENTION_REPO,
                        deleteReferrers: false,
                        deleteUntagged: true,
                        KeepTags: [
                            { patterns: [".*"] }
                        ]
                    }
                }

                {
                    distSpecVersion: "1.0.1",
                    storage: {
                        rootDirectory: /var/lib/registry,
                        dedupe: false,
                        ...$s3,
                        gc: true,
                        gcDelay: "24h",
                        gcInterval: "24h",
                        retention: {
                            dryRun: false,
                            delay: "0h",
                            policies: [
                                {
                                    repositories: [ infra/**, base/**, mid/** ],
                                    deleteReferrers: false,
                                    deleteUntagged: true,
                                    KeepTags: [
                                        { patterns: [".*"] }
                                    ]
                                },
                                {
                                    repositories: [ ** ],
                                    deleteReferrers: false,
                                    deleteUntagged: true,
                                    keepTags: [
                                        { patterns: [latest, __] }
                                    ]
                                },
                                ...$retention,
                                {
                                    repositories: [ ** ],
                                    deleteReferrers: true,
                                    deleteUntagged: true,
                                    keepTags: [
                                        { patterns: [".*"], mostRecentlyPushedCount: 5}
                                    ]
                                }
                            ]
                        }
                    },
                    http: {
                        address: "0.0.0.0",
                        port: "5000"
                    },
                    log: {
                        level: debug
                    },
                    extensions: {
                        search: {
                            enable: true
                        },
                        ui: {
                            enable: true
                        },
                        mgmt: {
                            enable: false
                        }
                    }
                }
                | to json
                | save -f /etc/zot/config.json
                mut cmd = ["/usr/local/bin/zot" serve /etc/zot/config.json]
                pueue-extend default 1
                pueue add --group default -l ferron -- ($cmd | str join " ")
            }

            run-zot
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save entrypoint/zot.nu
        }
    }
}
