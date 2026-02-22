use ./libs.nu *
use ../../../libs *

export def main [pgrx tags context] {
    sync pg_vector {
        repo: 'duckdb/pg_duckdb'
        version: []
    } $tags {|cx|
    }
}
