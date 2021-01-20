import streams
import unittest

import configparser


test "converters from python 3.5":
        var cfg = ConfigParser()
        cfg.read_string(
            """
        [s]
        str = string
        int = 1
        float = 0.5
        list = a b c d e f g
        bool = yes
        """
        )
        var s = cfg["s"]
        check s["str"] == "string"
        check s["int"] == "1"
        check s["float"] == "0.5"
        check s["list"] == "a b c d e f g"
        check s["bool"] == "yes"
        check cfg.get("s", "str") == "string"
        check cfg.get("s", "int") == "1"
        check cfg.get("s", "float") == "0.5"
        check cfg.get("s", "list") == "a b c d e f g"
        check cfg.get("s", "bool") == "yes"
        check cfg.get("s", "str") == "string"
        check cfg.getint("s", "int") == 1
        check cfg.getfloat("s", "float") == 0.5
        check cfg.getlist("s", "list") == ["a", "b", "c", "d", "e", "f", "g"]
        check cfg.getboolean("s", "bool") == true
        check s.get("str") == "string"
        check s.getint("int") == 1
        check s.getfloat("float") == 0.5
        check s.getlist("list") == ["a", "b", "c", "d", "e", "f", "g"]
        check s.getboolean("bool") == true

# vi: ft=nim:et:ts=4:fdm=marker
