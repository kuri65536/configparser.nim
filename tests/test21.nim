#[

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#
import sequtils
import streams
import strutils
import system
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


proc gen21(delimiters: seq[string],  # {{{1
           inline_comment_prefixes: seq[string],
           comment_prefixes: seq[string],
           section: string): ConfigParser =
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
    ], delims=delimiters, cmtpfx=inline_comment_prefixes)
    config_string = config_string.replace("{section}", section)
    if cfg.allow_no_value:
        config_string &= "[Valueless]\noption-without-value\n"

    var cf = initConfigParser(
            delimiters,
            inline_comment_prefixes = inline_comment_prefixes,
            default_section = section)
    cf.read_string(config_string)
    return cf


proc fn21(f_space: bool, delimiters = @["=", ":"],  # {{{1
          inline_comment_prefixes = @["#", ";"],
          comment_prefixes = @["#", ";"],
          section = "DEFAULT"): bool =
        var cf = gen21(delimiters, inline_comment_prefixes,
                       comment_prefixes, section)

        var output = newStringStream()
        cf.write(output, space_around_delimiters=f_space)
        var delimiter = if f_space: " 0 "
                        else:       "0"
        delimiter = delimiter.replace("0", delimiters[0])
        var exp_seq1 = @[
            "[{1}]",
            "foo{0}another very",
            "\tlong line",
            "",
        ]
        var exp_seq2 = @[
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
        ]
        if section < "Long Line":
            exp_seq1 = exp_seq1 & exp_seq2
        else:
            exp_seq1 = exp_seq2 & exp_seq1
        var exp = join(exp_seq1, "\n").replace(
                       "{0}", delimiter).replace("{1}", section)
        if cfg.allow_no_value:
            exp &= "[Valueless]\noption-without-value\n\n"
        var (n, exp_lines) = (0, exp.split("\n"))
        var f_result = true
        for line in output.lines():
            if n >= len(exp_lines):
                f_result = false
                break
            if line != exp_lines[n]:
                f_result = false
                echo "check failed: exp,", exp_lines[n], ",got,", line
            n += 1
        return f_result


test "api: write()":  # {{{1
    check fn21(false)
    check fn21(true)


test "parameter: delimiters":  # {{{1
    check fn21(false, @["$", ":="])
    check fn21(false, @[":=", "&"])


test "parameter: comment_prefixes":  # {{{1
    check fn21(false, comment_prefixes = @["//", "\""])


test "parameter: inline_comment_prefixes":  # {{{1
    check fn21(false, inline_comment_prefixes = @["//", "\""])


test "parameter: default_section":  # {{{1
    check fn21(false, section = "public")


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker
