import algorithm
import streams
import system
import unittest

import configparser


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


proc config_for_interpolate_test(): ConfigParser =  # {{{1
    result = initConfigParser(
        interpolation = initBasicInterpolation())
    result.read_string("""
        [Foo]
        bar = something %(with1)s interpolation (1 step)
        bar9 = something %(with9)s lots of interpolation (9 steps)
        bar10 = something %(with10)s lots of interpolation (10 steps)
        bar11 = something %(with11)s lots of interpolation (11 steps)
        with11 = %(with10)s
        with10 = %(with9)s
        with9 = %(with8)s
        with8 = %(With7)s
        with7 = %(WITH6)s
        with6 = %(with5)s
        With5 = %(with4)s
        WITH4 = %(with3)s
        with3 = %(with2)s
        with2 = %(with1)s
        with1 = with

        [Mutual Recursion]
        foo = %(bar)s
        bar = %(foo)s

        [Interpolation Error]
        # no definition for 'reference'
        name = %(reference)
        """)


test "interpolation - basic - step1,3-7":
    var cf = config_for_interpolate_test()
    check cf.get("Foo", "bar") == "something withs interpolation (1 step)"
    check cf.get("Foo", "with3") == "withss"
    check cf.get("Foo", "with4") == "withsss"
    check cf.get("Foo", "with5") == "withssss"
    check cf.get("Foo", "with6") == "withsssss"
    check cf.get("Foo", "with7") == "withssssss"


test "interpolation - basic - step9":
    var cf = config_for_interpolate_test()
    check(cf.get("Foo", "bar9") ==
          "something withsssssssss lots of interpolation (9 steps)")


test "interpolation - basic - step10":
    var cf = config_for_interpolate_test()
    check(cf.get("Foo", "bar10") ==
          "something withssssssssss lots of interpolation (10 steps)")


test "interpolation - too deep":
    var cf = config_for_interpolate_test()
    try:
        discard cf.get("Foo", "bar11")
        check false
    except InterpolationDepthError:
        discard


test "interpolation - missing value":
    var cf = config_for_interpolate_test()
    try:
        discard cf.get("Interpolation Error", "name")
        check false
    except InterpolationMissingOptionError:
        discard


proc config_for_extended_interpolate_test(): ConfigParser =  # {{{1
    result = initConfigParser(
        interpolation = initExtendedInterpolation())
    result.read_string("""
        [Foo]
        bar = something ${with1}s interpolation (1 step)
        bar9 = something ${with9}s lots of interpolation (9 steps)
        bar10 = something ${with10}s lots of interpolation (10 steps)
        bar11 = something ${with11}s lots of interpolation (11 steps)
        with11 = ${with10}s
        with10 = ${with9}s
        with9 = ${with8}s
        with8 = ${With7}s
        with7 = ${WITH6}s
        with6 = ${Foo2:with5}s
        WITH4 = ${with3}s
        with3 = ${Foo2:with2}s
        with1 = with

        [Foo2]
        with2 = ${Foo:with1}s
        With5 = ${Foo:with4}s

        [Mutual Recursion]
        foo = ${bar}s
        bar = ${foo}s

        [Interpolation Error]
        # no definition for 'reference'
        name = %(reference)
        """)


test "extended interpolation - basic - step1,3-7":
    var cf = config_for_extended_interpolate_test()
    check cf.get("Foo", "bar") == "something withs interpolation (1 step)"
    check cf.get("Foo", "with3") == "withss"
    check cf.get("Foo", "with4") == "withsss"
    check cf.get("Foo2", "with5") == "withssss"
    check cf.get("Foo", "with6") == "withsssss"
    check cf.get("Foo", "with7") == "withssssss"


test "extended interpolation - basic - step9":
    var cf = config_for_extended_interpolate_test()
    check(cf.get("Foo", "bar9") ==
          "something withsssssssss lots of interpolation (9 steps)")


test "extended interpolation - basic - step10":
    var cf = config_for_extended_interpolate_test()
    check(cf.get("Foo", "bar10") ==
          "something withssssssssss lots of interpolation (10 steps)")


test "extended interpolation - too deep":
    var cf = config_for_interpolate_test()
    try:
        discard cf.get("Foo", "bar11")
        check false
    except InterpolationDepthError:
        discard


test "extended interpolation - mutual recursion":
    var cf = config_for_interpolate_test()
    try:
        discard cf.get("Mutual Recursion", "foo")
        check false
    except InterpolationDepthError:
        discard


test "extended interpolation - missing value":
    var cf = config_for_interpolate_test()
    try:
        discard cf.get("Interpolation Error", "name")
        check false
    except InterpolationMissingOptionError:
        discard


test "malformatted interpolation":  # {{{1
    discard
    #[
    cf = self.fromstring(
        "[sect]\n" "option1{eq}foo\n".format(eq=self.delimiters[0])
    )

    self.assertEqual(cf.get('sect', "option1"), "foo")

    cf.set("sect", "option1", "%foo")
    self.assertEqual(cf.get('sect', "option1"), "%foo")
    cf.set("sect", "option1", "foo%")
    self.assertEqual(cf.get('sect', "option1"), "foo%")
    cf.set("sect", "option1", "f%oo")
    self.assertEqual(cf.get('sect', "option1"), "f%oo")

    # bug #5741: double percents are *not* malformed
    cf.set("sect", "option2", "foo%%bar")
    self.assertEqual(cf.get("sect", "option2"), "foo%%bar")
    ]#


#[
test "read file":  # covered in read()
            var parser = ConfigParser()
            parser.read("tests/test.ini")
            check parser.sections().contains("Foo Bar") == true
            check parser.has_option("Foo Bar", "foo") == true
            check parser.get("Foo Bar", "foo") == "newbar"


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
