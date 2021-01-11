#[

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#
import algorithm
import streams
import strutils
import tables
import unittest

import py_configparser

type
  Config = ref object of RootObj  # {{{1
    allow_no_value: bool
    comment_prefixes: seq[string]
    default_section: string
    delimiters: seq[string]
    strict: bool

let cfg = Config(allow_no_value: false,
                 comment_prefixes: @["#", ";"],
                 default_section: "",
                 delimiters: @["=", ";"],
                 strict: true)

let basic_test_sections = @["include comments",
                            "Simple Test",
                            "sample for i18n",
                            "LONGLINE",
                            "Section\\with$weird%characters[\t",
                            "include spaces",
                            "include spaces",
                            "include prefix spaces",
                            "Types"]
let basic_test_pairs = @[("ghi", "JKL"), ("simplekey", "value")]


proc almostEqual(f1, f2: float): bool =  # {{{1
    return abs(f1 - f2) < 1e-12


proc conv_delim(src: openArray[string]): string =  # {{{1
    var ret = join(src, "\n")
    ret = ret.replace("{d0}", cfg.delimiters[0])
    ret = ret.replace("{d1}", cfg.delimiters[1])
    ret = ret.replace("{c0}", cfg.comment_prefixes[0])
    ret = ret.replace("{c1}", cfg.comment_prefixes[1])
    return ret


test "can basic parse":
    var ini = ConfigParser()
    ini.read_string("test = test")
    check ini.get("", "test") == "test"

test "can basic parse - 2":
    var ini = ConfigParser()
    ini.read_file(newStringStream("test = test\ntest2 = aaa"))
    check ini.get("", "test2") == "aaa"

test "can basic parse - 3":
    var ini = ConfigParser()
    ini.read_string("test = test\ntest2 = aaa\ntest3 = abc")
    check ini.get("", "test3") == "abc"

test "can basic parse - sections":
    var ini = ConfigParser()
    ini.read_string("test = test\n" &
                             "[sec1]\naaa = bbb\n" &
                             "[sec2]\nabc = bcd\n" &
                             "[sec3]\nhij = lmn")
    check ini.get("", "test") == "test"
    check ini.get("sec1", "aaa") == "bbb"
    check ini.get("sec2", "abc") == "bcd"
    check ini.get("sec3", "hij") == "lmn"

proc basic_test(): ConfigParser =  # {{{1
    var E = basic_test_sections
    if cfg.allow_no_value:
        E.add("NoValue")
    E.sort(system.cmp)

    var src = conv_delim([
        "[Simple Test]",
        "simplekey{d0}simplevalue",
        "[include spaces]",
        "simplekey {d0} simple_value",
        "123 {d1} keys can be numbers",
        "[include prefix spaces]",
        "   simplekey {d0} value",
        "\tabc {d0} def",
        "[include comments]",
        "simplekey{d1} bar4 {c1} comment",
        "ghi{d0}JKL {c0}no spaces",
        "[LONGLINE]",
        "simplekey{d1} long line sample, this is a simple long line value ",
        "for parser.",
        "[Section\\with$weird%characters[\t]",
        "[sample for i18n]",
        "simplekey{d0}Default",
        "simplekey[en]{d0}English",
        "simplekey[ja]{d0}Japanese",
        "simplekey[th]{d1} Thai",
        "[include spaces]",
        "key include spaces {d0} value",
        "kye2 include spaces {d1} value with spaces",
        "[value for various types]",
        "int {d1} 123",
        "bool {d0} NO",
        "float {d0} 1.234",
        ])

    if cfg.allow_no_value:
        src &= "\n\n[NoValue]\noption-without-value\n"
    var ret = ConfigParser()
    ret.read_string(src)
    return ret


test "can list up sections":  # {{{1
    var cf = basic_test()
    var L = cf.sections()
    L.sort(system.cmp)
    check L == basic_test_sections


test "api: parser.1tems()":  # {{{1
    var cf = basic_test()
    var L = cf.items("include prefix spaces")
    L.sort(system.cmp)
    check L == basic_test_pairs


test "api: parser.sections() mapping access":  # {{{1
    var cf = basic_test()
    var L: seq[string] = @[]
    for section in cf.sections():
        L.add(section)
    L.sort(system.cmp)
    var E = basic_test_sections
    E.add(cfg.default_section)
    E.sort(system.cmp)
    check L == E


test "api: parser and section mapping access":  # {{{1
    var cf = basic_test()
    var L = cf["include prefix spaces"].items()
    L.sort(system.cmp)
    var F = basic_test_pairs
    check L == F

    var section = cf["include prefix spaces"]
    check section["simplekey"] == "value"
    check section["ghi"] == "JKL"

    check cf["Simple Test"]["simplekey"] == "simplevalue"
    check cf["include spaces"]["simplekey"] == "simple_value"
    check cf["include comments"]["simplekey"] == "bar4"
    check cf["include comments"]["ghi"] == "JKL"

    check cf["include spaces"]["key with spaces"] == "value"
    check cf["include spaces"]["another with spaces"] == "splat!"
    check cf["LONGLINE"]["simplekey"] ==
            "long line sample, this is a simple long line value for parser\nlikes it."
    if cfg.allow_no_value:
        check cf["NoValue"]["option-without-value"] == ""


test "api: parser.items() mapping access 2":  # {{{1
    var cf = basic_test()
    var nam_sec = cf.items()
    nam_sec.sort(system.cmp)
    check len(nam_sec) == len(basic_test_sections)
    #[ TODO(shimoda): impl.
    for name, section in nam_sec:
        check name == section.name
    ]#
    check cf.defaults() == cf[cfg.default_section]


test "api: parser.get*()":  # {{{1
    var cf = basic_test()
    check cf.get("Simple Test", "simplekey") == "simplevalue"
    check cf.get("include spaces", "simplekey") == "simple_value"
    check cf.get("include prefix spaces", "simplekey") == "value"
    check cf.get("include prefix spaces", "ghi") == "JKL"
    check cf.get("include comments", "simplekey") == "bar4"
    check cf.get("include comments", "ghi") == "JKL"
    check cf.get("include spaces", "key with spaces") == "value"
    check cf.get("include spaces", "another with spaces") == "splat!"
    check cf.getint("Types", "int") == 123
    check cf.get("Types", "int") == "123"
    check cf.getfloat("Types", "float") == 1.234
    check cf.get("Types", "float") == "1.234"
    check cf.getboolean("Types", "boolean") == false
    check cf.get("include spaces", "123") == "keys can be numbers"
    if cfg.allow_no_value:
        check cf.get("NoValue", "option-without-value") == ""


test "api: parser.get*() w/fallback":  # {{{1
    var cf = basic_test()
    check cf.get("Simple Test", "simplekey", fallback="ghi") == "simplevalue"
    check cf.get("No Such Simple Test", "simplekey", fallback="ghi") == "ghi"
    check cf.get("Simple Test", "no-such-foo", fallback="ghi") == "ghi"
    check cf.get("include spaces", "simplekey", fallback="") == "simple_value"
    check cf.get("No Such include spaces", "simplekey", fallback="") == ""

    check cf.getint("Types", "int", fallback=18) == 42
    check cf.getint("Types", "no-such-int", fallback=18) == 18

    check cf.getfloat("Types", "float", fallback=0.0) == 0.44
    check cf.getfloat("Types", "no-such-float", fallback=0.0) == 0.0

    check cf.getboolean("Types", "boolean", fallback=true) == false
    check cf.getboolean("Types", "no-such-boolean", fallback=true) == true
    check cf.getboolean("No Such Types", "boolean", fallback=true) == true
    if cfg.allow_no_value:
        check cf.getboolean("NoValue", "option-without-value",
                            fallback=false) == false
        check cf.getboolean("NoValue", "no-such-option-without-value",
                            fallback=false) == false


test "api: parser.get*() w/vars":  # {{{1
    var cf = basic_test()
    var vars = newTable[string, string]()
    vars.add("simplekey", "ghi")
    check cf.get("Simple Test", "simplekey", vars=vars) == "ghi"

    expect NoSectionError:
        discard cf.get("No Such Simple Test", "simplekey")

    expect NoOptionError:
        discard cf.get("Simple Test", "no-such-foo")

    expect NoOptionError:
        discard cf.getint("Types", "no-such-int")

    expect NoOptionError:
        discard cf.getfloat("Types", "no-such-float")

    expect NoOptionError:
        discard cf.getboolean("Types", "no-such-boolean")

    expect KeyError:  # {{{1
        discard cf["No Such Simple Test"]["simplekey"]

    expect KeyError:  # {{{1
        discard cf["Simple Test"]["no-such-foo"]

    expect KeyError:  # {{{1
        discard cf["No Such Simple Test"].get("simplekey", fallback="ghi")

    expect KeyError:  # {{{1
        discard cf["No Such include spaces"].get("simplekey", fallback="1")


test "API in sections":  # {{{1
    var cf = basic_test()
    var section = cf["include prefix spaces"]
    #[ TODO(shimoda): impl.
    check section.name == "include prefix spaces"
    check section.parser == cf
    ]#

    # test vars= and fallback=
    var vars = newTable({"test": "vars"})
    check cf["Simple Test"].get("simplekey", "ghi") == "simplevalue"
    check cf["Simple Test"].get("simplekey", fallback="ghi") == "simplevalue"
    check cf["Simple Test"].get("simplekey", vars=vars) == "ghi"

    check cf["Simple Test"].get("no-such-foo", "ghi") == "ghi"
    check cf["Simple Test"].get("no-such-foo", fallback="ghi") == "ghi"
    check cf["Simple Test"].get("no-such-foo") == ""
    check cf["include spaces"].get("simplekey", "") == "simple_value"
    check cf["include spaces"].get("simplekey", fallback="") == "simple_value"

    check cf["Types"].getint("int", 18) == 42
    check cf["Types"].getint("int", fallback=18) == 42
    check cf["Types"].getint("no-such-int", 18) == 18
    check cf["Types"].getint("no-such-int", fallback=18) == 18

    check almostEqual(cf["Types"].getfloat("float", 0.0), 0.44)
    check almostEqual(cf["Types"].getfloat("float", fallback=0.0), 0.44)
    check almostEqual(cf["Types"].getfloat("no-such-float", 0.0), 0.0)
    check almostEqual(cf["Types"].getfloat("no-such-float", fallback=0.0), 0.0)

    check cf["Types"].getboolean("boolean", true) == false
    check cf["Types"].getboolean("boolean", fallback=true) == false
    check cf["Types"].getboolean("no-such-boolean", true) == true
    check cf["Types"].getboolean("no-such-boolean", fallback=true) == true

    if cfg.allow_no_value:
        check cf["NoValue"].get("option-without-value", false) == false
        check cf["NoValue"].get("option-without-value", fallback=false) == false
        check cf["NoValue"].get("no-such-option-without-value", false) == false
        check cf["NoValue"].get("no-such-option-without-value", fallback=false) == false

    # Make sure the right things happen for remove_section() and
    # remove_option(); added to include check for SourceForge bug #123324.

    cf[cfg.default_section]["this_value"] = "1"
    cf[cfg.default_section]["that_value"] = "2"

    # API access
    check cf.has_option("include spaces", "key with spaces") == false
    expect NoSectionError:
        cf.remove_section(cfg.default_section)
    # remove_option() failed to report existence of option
    expect NoOptionError:
        cf.remove_option("Simple Test", "simplekey")
    # remove_option() failed to remove option"
    check cf.has_option("Simple Test", "simplekey") == false
    # remove_option() failed to report non-existence of option that was removed
    expect NoOptionError:
        cf.remove_option("Simple Test", "simplekey")
    expect NoOptionError:
        cf.remove_option("Simple Test", "this_value")
    cf.remove_option(cfg.default_section, "this_value")
    check cf.has_option("Simple Test", "this_value") == false
    check cf.remove_option(cfg.default_section, "this_value") == false

    #[
    with self.assertRaises(configparser.NoSectionError) as cm:
        cf.remove_option("No Such Section", "simplekey")
    ]#
    expect NoSectionError:
        check getCurrentExceptionMsg() == "No Such Section"
    expect NoSectionError:
        check getCurrentExceptionMsg() == "No Such Section"

    check cf.get("LONGLINE", "simplekey") ==
        "long line sample, this is a simple long line value for parser\nlikes it."

    #[ table access
    TODO(shimoda): implement table style: cf.del("Types")
    TODO(shimoda): implement table style: check ("Types" in cf) == false
    expect: NoSection:
        cf.del("Types")
    expect: ValueError:
        cf.del(self.default_section)
    ]#
    cf["include spaces"].del("simplekey")
    check "simplekey" in cf["include spaces"] == false
    expect KeyError:
        cf["include spaces"].del("simplekey")
    check "that_value" in cf["include spaces"] == true
    expect KeyError:
        cf["include spaces"].del("that_value")
    cf[cfg.default_section].del("that_value")
    check "that_value" in cf["include spaces"] == false
    expect KeyError:
        cf[cfg.default_section].del("that_value")
    expect KeyError:
        cf["No Such Section"].del("simplekey")

    # Don't add new asserts below in this method as most of the options
    # and sections are now removed.


test "API, in sections - read dups":  # {{{1
    var cf = basic_test()

    expect DuplicateOptionError:
        if not cfg.strict:
            raise newException(DuplicateOptionError, "skipped")
        cf.read_string(conv_delim(["[Duplicate Options Here]",
                                   "option {d0} with a value",
                                   "option {d1} with another value"]))

    expect DuplicateSectionError:
        if not cfg.strict:
            raise newException(DuplicateOptionError, "skipped")
        cf.read_string(conv_delim(["[And Now For Something]",
                                   "completely different {d0} True",
                                   "[And Now For Something]",
                                   "the larch {d1} 1"]))


test "can load duplicated contents":  # {{{1
    if cfg.strict:
        skip()
    var cf = basic_test()
    var (d1, d2) = (cfg.delimiters[0], cfg.delimiters[1])
    cf.read_string(conv_delim([
        "[Duplicate Options Here]",
        "option {d0} with a value",
        "option {d1} with another value"]))

    cf.read_string(conv_delim([
        "[And Now For Something]",
        "completely different {d0} True",
        "[And Now For Something]",
        "the larch {d1} 1"]))


test "can omit comment 1":
    var ini = initConfigParser()
    ini.read_string("test = test  ; test comment")
    check ini.get("", "test") == "test"

test "can omit comment 2 - sections":
    var ini = ConfigParser()
    ini.read_string("[sec1]  # comment\naaa = bbb\n" &
                             "[sec2]# comment\nabc = bcd\n" &
                             "[  sec3  ]   \nhij = lmn")
    check ini.sections().contains("sec1")
    check ini.sections().contains("sec2")
    check ini.sections().contains("sec3")

test "can check options 1":
    var ini = ConfigParser()
    ini.read_string("[sec1]  # comment\naaa = bbb\n" &
                             "[sec2]# comment\nabc = bcd\n" &
                             "[  sec3  ]   \nhij = lmn")
    check ini.has_option("sec1", "aaa") == true
    check ini.has_option("sec1", "bbb") == false

test "fallback test 1":
    var ini = ConfigParser()
    ini.read_string("test = default\n" &
                             "[sec1]\ntest = input\n" &
                             "[sec2]\nabc = input\n" &
                             "[sec3]\nhij = input")
    var vars = newTable({"test": "vars"})
    check ini.get("sec1", "test") == "input"
    check ini.get("sec2", "abc") == "input"
    check ini.get("sec2", "test") == "default"
    check ini.get("sec2", "test", fallback = "fb") == "default"
    check ini.get("sec2", "test", vars = vars) == "vars"
    check ini.get("sec3", "none", fallback = "fb") == "fb"

test "fallback test 2":
    var ini = ConfigParser()
    ini.read_file(newStringStream("[sec1]\na = 1\n" &
                                  "[sec2]\nb = 2.5\n" &
                                  "[sec3]\nc = true\n" &
                                  "[sec4]\nd = 1 2 3 4 5"))
    check ini.getint("sec1", "a") == 1
    check ini.getint("sec1", "b", fallback=2) == 2
    check ini.getfloat("sec2", "b") == 2.5
    check ini.getfloat("sec2", "c", fallback=3.5) == 3.5
    check ini.getboolean("sec3", "c") == true
    check ini.getboolean("sec3", "d", fallback=false) == false
    check ini.getboolean("sec3", "d", fallback=true) == true
    check ini.getlist("sec4", "d") == @["1", "2", "3", "4", "5"]
    check ini.getlist("sec4", "e", fallback=(true, @["10"])) == @["10"]


proc cfg_multiline(): ConfigParser =  # {{{1
    var cfg = initConfigParser()
    cfg.read_string("""[
        [LONGLINE]
        foo = long line sample, this is a simple long line value for parser
           likes it.
        []
        bar= another very
         long line
        [LONGLINE - With Comments!]
        test = we        ; can\n"
               also      ; place\n"
               comments  ; in\n"
               multiline ; values"
        """)
    return cfg


test "multiline - 1":
    var cfg = cfg_multiline()
    check cfg.get("LONGLINE", "simplekey") ==
        "long line sample, this is a simple long line value for parser likes it."

test "multiline - 2":
    var cfg = cfg_multiline()
    check cfg.get("LONGLINE", "bar") == "another very long line"

test "multiline - 3":
    var cfg = cfg_multiline()
    check cfg.get("LONGLINE - With Comments!", "test") ==
                  "we also comments multiline"


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker
