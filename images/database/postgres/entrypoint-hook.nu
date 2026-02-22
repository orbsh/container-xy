#!/usr/bin/env nu

def main [...args] {
    open /usr/local/bin/docker-entrypoint.sh
    | lines
    | each {|x|
        if ('exec "$@"' in $x) {
            [
                'nu /usr/local/bin/entrypoint-extend.nu'
                $x
            ]
        } else if ('docker_temp_server_stop' in $x) {
            [
                $x
                r#'echo "include_if_exists = 'usr.conf'">> $PGDATA/postgresql.conf'#
            ]
        } else {
            [
                $x
            ]
        }
    }
    | flatten
    | str join (char newline)
    | save -f /usr/local/bin/docker-entrypoint-patched.sh

    chmod +x /usr/local/bin/docker-entrypoint-patched.sh

    if ($args | is-empty) {
        ^docker-entrypoint-patched.sh "postgres"
    } else {
        ^docker-entrypoint-patched.sh ...$args
    }
}
