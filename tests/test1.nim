# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.
import streams
import tables
import unittest

import py_configparser


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
    check ini.getint("sec1", "b", fallback=(true, 2)) == 2
    check ini.getfloat("sec2", "b") == 2.5
    check ini.getfloat("sec2", "c", fallback=(true, 3.5)) == 3.5
    check ini.getboolean("sec3", "c") == true
    check ini.getboolean("sec3", "d", fallback=(true, false)) == false
    check ini.getboolean("sec3", "d", fallback=(true, true)) == true
    check ini.getlist("sec4", "d") == @["1", "2", "3", "4", "5"]
    check ini.getlist("sec4", "e", fallback=(true, @["10"])) == @["10"]


proc cfg_multiline(): ConfigParser =  # {{{1
    var cfg = initConfigParser()
    cfg.read_string("""[
        [Long Line]
        foo = this line is much, much longer than my editor
           likes it.
        []
        bar= another very
         long line
        [Long Line - With Comments!]
        test = we        ; can\n"
               also      ; place\n"
               comments  ; in\n"
               multiline ; values"
        """)
    return cfg


test "multiline - 1":
    var cfg = cfg_multiline()
    check cfg.get("Long Line", "foo") ==
        "this line is much, much longer than my editor likes it."

test "multiline - 2":
    var cfg = cfg_multiline()
    check cfg.get("Long Line", "bar") == "another very long line"

test "multiline - 3":
    var cfg = cfg_multiline()
    check cfg.get("Long Line - With Comments!", "test") ==
                  "we also comments multiline"


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker
