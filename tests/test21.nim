import streams
import unittest

import configparser


test "comment handlings":  # {{{1
    var cf = initConfigParser(
        comment_prefixes = @["#", ";"],
        inline_comment_prefixes = @[";"])
    cf.read_string("""
        [Commented Bar]
        baz=qwe ; a comment
        foo: bar # not a comment!
        # but this is a comment
        ; another comment
        quirk: this;is not a comment
        ; a space must precede an inline comment
        """)
    check cf.has_section("Commented Bar") == true
    echo cf.options("Commented Bar")
    check cf.get("Commented Bar", "foo") == "bar # not a comment!"
    check cf.get("Commented Bar", "baz") == "qwe"
    check cf.get("Commented Bar", "quirk") == "this;is not a comment"


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker
