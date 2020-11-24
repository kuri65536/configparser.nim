import algorithm
import streams
import system
import unittest

import py_configparser


test "can remove section":
    var cf = ConfigParser()
    cf.read("tests/test.ini")
    cf.remove_section("Foo Bar")
    check cf.has_section("Foo Bar") == false

    try:
        cf.remove_section("Foo Bar")
        check false
    except:
        discard


test "can add section":
    var cf = initConfigParser()
    cf.add_section("A")
    cf.add_section("a")
    cf.add_section("B")
    var seq = cf.sections()
    seq.sort(system.cmp)
    check seq[0] == "A"
    check seq[1] == "B"
    check seq[2] == "a"


test "can add option":
    var cf = initConfigParser()
    cf.add_section("a")
    cf.set("a", "B", "value")
    check cf.options("a") == @["b"]  # B->b by optionxform.
    check cf.get("a", "b") == "value"


test "case sensitivity":
    var cf = initConfigParser()
    cf.add_section("A")
    cf.set("A", "B", "value")  # recognize a and A, by previous test.
    var opts = cf.options("A")    # and B->b by optionxform.
    check opts.contains("B") == false


test "read file":  # covered in read()
            var parser = ConfigParser()
            parser.read("tests/test.ini")
            check parser.sections().contains("Foo Bar") == true
            check parser.has_option("Foo Bar", "foo") == true
            check parser.get("Foo Bar", "foo") == "newbar"

#[
test "read iterable":
        var parser = ConfigParser()
        var lines = ("[Foo Bar]",
                     "foo=newbar", )
        parser.read(lines)
        check ini."Foo Bar", parser)
        check("foo", parser["Foo Bar"])
        self.assertEqual(parser["Foo Bar"]["foo"], "newbar")

test "readline generator"
        var parser = ConfigParser()
        with self.assertRaises(TypeError):
            parser.read_file(FakeFile())
        parser.read_file(readline_generator(FakeFile()))
        self.assertIn("Foo Bar", parser)
        self.assertIn("foo", parser["Foo Bar"])
        self.assertEqual(parser["Foo Bar"]["foo"], "newbar")

test "source as bytes":  # build ok at rev.8
        var lines = newStringStream("[badbad]\n[badbad]")
        var parser = ConfigParser()
        try:
            parser.read(lines)  # , source="badbad")
            check false
        except DuplicateSectionError as dse:
            check repr(dse) ==
                "While reading from 'badbad' [line  2]: section 'badbad' " &
                "already exists"

        lines = newStringStream("[badbad]\n" &
                                "bad = bad\n" &
                                "bad = bad")
        parser = ConfigParser()
        try:
            parser.read(lines)  # , source=b"badbad")
            check false
        except DuplicateOptionError as dse:
            check repr(dse) ==
                "While reading from 'badbad' [line  3]: option 'bad' " &
                "in section 'badbad' already exists"

        lines = newStringStream("[badbad]\n" &
                                "= bad")
        parser = ConfigParser()
        try:
            parser.read(lines)  # , source=b"badbad")
            check false
        except ParsingError as dse:
            check repr(dse) ==
                "Source contains parsing errors: 'badbad'\n\t[line  2]: " &
               "'= bad'"

        lines = newStringStream("[badbad\n" &
                                "bad = bad")
        parser = ConfigParser()
        try:
            parser.read(lines)  # , source=b"badbad")
        except MissingSectionHeaderError as dse:
            check repr(dse) ==
                "File contains no section headers.\nfile: 'badbad', " &
                "line: 1\n'[badbad'"
]#

# vi: ft=nim:et:ts=4:fdm=marker:nowrap
