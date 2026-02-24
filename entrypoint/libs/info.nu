export def main [...msg] {
    print $"(date now | format date '%FT%T%.3f')│($msg | str join ' ')"
}
