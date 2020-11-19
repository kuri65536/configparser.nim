# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.
import streams
import unittest

import py_configparser


test "can basic parse":
    var ini = ConfigParser()
    ini.read(newStringStream("test = test"))
    check ini.get("", "test") == "test"

test "can basic parse - 2":
    var ini = ConfigParser()
    ini.read(newStringStream("test = test\ntest2 = aaa"))
    check ini.get("", "test2") == "aaa"

test "can basic parse - 3":
    var ini = ConfigParser()
    ini.read(newStringStream("test = test\ntest2 = aaa\ntest3 = abc"))
    check ini.get("", "test3") == "abc"

test "can basic parse - sections":
    var ini = ConfigParser()
    ini.read(newStringStream("test = test\n" &
                             "[sec1]\naaa = bbb\n" &
                             "[sec2]\nabc = bcd\n" &
                             "[sec3]\nhij = lmn"))
    check ini.get("", "test") == "test"
    check ini.get("sec1", "aaa") == "bbb"
    check ini.get("sec2", "abc") == "bcd"
    check ini.get("sec3", "hij") == "lmn"

test "can omit comment 1":
    var ini = ConfigParser()
    ini.read(newStringStream("test = test  # test comment"))
    check ini.get("", "test") == "test"

test "can omit comment 2 - sections":
    var ini = ConfigParser()
    ini.read(newStringStream("[sec1]  # comment\naaa = bbb\n" &
                             "[sec2]# comment\nabc = bcd\n" &
                             "[  sec3  ]   \nhij = lmn"))
    check ini.sections().contains("sec1")
    check ini.sections().contains("sec2")
    check ini.sections().contains("sec3")

