#!/usr/bin/env nu

let env_to_save = $env
    | transpose key value
    | where key =~ '_|HOME|ROOT|PATH|TIMEZONE|HOSTNAME|DIR|VERSION|LANG|TIME|MODULE|BUFFERED'
    | where key !~ '^(_|HOME|USER|LS_COLORS)$'

let env_lines = $env_to_save
    | each { |row| $"($row.key)=($row.value)" }
    | str join "\n"

if ($env_lines | is-not-empty) {
    $"($env_lines)\n" | sudo tee -a /etc/environment | ignore
}
