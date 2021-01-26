#[

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#
import streams
import strutils
import unittest

import configparser
import ./utils


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


test "api: write()":  # {{{1
    let section = "DEFAULT"
    var config_string = conv_delim(@[
        "[Long Line]",
        "foo{d0} this line is much, much longer than my editor",
        "   likes it.",
        "[{section}]",
        "foo{d1} another very",
        " long line",
        "[Long Line - With Comments!]",
        "test {d1} we        {c1} can",
        "          also      {c1} place",
        "          comments  {c1} in",
        "          multiline {c1} values",
    ]).replace("{section}", section)
    if cfg.allow_no_value:
        config_string &= "[Valueless]\noption-without-value\n"

    var cf = initConfigParser()
    cf.read_string(config_string)

    proc fn(f_space: bool): void =
        var output = newStringStream()
        cf.write(output, space_around_delimiters=f_space)
        var delimiter = if f_space: " 0 "
                        else:       "0"
        delimiter = delimiter.replace("0", cfg.delimiters[0])
        var exp = join(@[
            "[{1}]",
            "foo{0}another very",
            "\tlong line",
            "",
            "[Long Line]",
            "foo{0}this line is much, much longer than my editor",
            "\tlikes it.",
            "",
            "[Long Line - With Comments!]",
            "test{0}we",
            "\talso",
            "\tcomments",
            "\tmultiline",
            "",
        ], "\n").replace("{0}", delimiter).replace("{1}", section)
        if cfg.allow_no_value:
            exp &= "[Valueless]\noption-without-value\n\n"
        var (n, exp_lines) = (0, exp.split("\n"))
        for line in output.lines():
            check n < len(exp_lines)
            check line == exp_lines[n]
            n += 1

    fn(false)
    fn(true)


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker
