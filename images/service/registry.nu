use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):ubuntu'
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
            use libs/tasks.nu

            def run-zot [] {
                let s3 = if ($env.S3_BACKEND? | is-empty) {
                    {}
                } else {
                    let o = $env.S3_BACKEND | from json
                    {
                        storageDriver: {
                            name: "s3",
                            regionendpoint: $o.endpoint,
                            forcepathstyle: $o.pathstyle?,
                            region: $o.region,
                            bucket: $o.bucket,
                            secure: $o.secure,
                            skipverify: $o.skipverify?,
                            accesskey: $o.accessKey,
                            secretkey: $o.secretKe
                        },
                    }
                }

                let retention = if ($env.RETENTION_REPO? | is-empty) {
                    []
                } else {
                    $env.RETENTION_REPO
                    | split row ','
                    | each {|x|
                        {
                            repositories: $x,
                            deleteReferrers: false,
                            deleteUntagged: true,
                            KeepTags: [
                                { patterns: [".*"] }
                            ]
                        }
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
                                    repositories: [ infra/**, base/**, library/** ],
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
                                        { patterns: [ latest, __ ] }
                                    ]
                                },
                                ...$retention,
                                {
                                    repositories: [ ** ],
                                    deleteReferrers: true,
                                    deleteUntagged: true,
                                    keepTags: [
                                        { patterns: [".*"], mostRecentlyPushedCount: 5 }
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

                let cmd = [/usr/local/bin/zot serve /etc/zot/config.json]
                | str join " "

                tasks spawn {
                    tag: zot
                    cmd: $cmd
                }
            }

            run-zot
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save entrypoint/zot.nu
        }
    }
}
