import unittest

import py_configparser


test "doesn't strip inline comment":
        #[
        delimiter occurs earlier without preceding space..
        ]#

        var cfg = ConfigParser(
                inline_comment_prefixes: @[";", "#", "//"])
        cfg.read_string("""
        [section]
        k1 = v1;still v1
        k2 = v2 ;a comment
        k3 = v3 ; also a comment
        k4 = v4;still v4 ;a comment
        k5 = v5;still v5 ; also a comment
        k6 = v6;still v6; and still v6 ;a comment
        k7 = v7;still v7; and still v7 ; also a comment
        [multiprefix]
        k1 = v1;still v1 #a comment ; yeah, pretty much
        k2 = v2 // this already is a comment ; continued
        k3 = v3;#//still v3# and still v3 ; a comment
        """
        )
        var s = "section"
        check cfg.get(s, "k1") == "v1;still v1"
        check cfg.get(s, "k2") == "v2"
        check cfg.get(s, "k3") == "v3"
        check cfg.get(s, "k4") == "v4;still v4"
        check cfg.get(s, "k5") == "v5;still v5"
        check cfg.get(s, "k6") == "v6;still v6; and still v6"
        check cfg.get(s, "k7") == "v7;still v7; and still v7"
        s = "multiprefix"
        check cfg.get(s, "k1") == "v1;still v1"
        check cfg.get(s, "k2") == "v2"
        check cfg.get(s, "k3") == "v3;#//still v3# and still v3"


# vi: ft=nim:et:ts=4:fdm=marker
