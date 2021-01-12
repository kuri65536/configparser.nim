#[
yet another python config parser for Nim
===============================================================================
- do not use regex.


## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

## Example <!-- {{{1 -->

```nim
import py_configparser

var cfg = initConfigParser()
cfg.read_file(paramStr(1))
echo cfg.get("some", "option")
```


### Examples

```ini
charset = "utf-8"
[Package]
name = "hello"
--threads:on
[Author]
name = "lihf8515"
qq = "10214028"
email = "lihaifeng@wxm.com"
```

### (under development) Creating a configuration file.

```nim
import py_configparser

var cfg = initConfigParser()
cfg.set("","charset","utf-8")
cfg.set("Package","name","hello")
cfg.set("Package","--threads","on")
cfg.set("Author","name","lihf8515")
cfg.set("Author","qq","10214028")
cfg.set("Author","email","lihaifeng@wxm.com")
cfg.writeConfig("config.ini")
```

### Reading a configuration file.

```nim
import parsecfg
var dict = loadConfig("config.ini")
var charset = dict.getSectionValue("","charset")
var threads = dict.getSectionValue("Package","--threads")
var pname = dict.getSectionValue("Package","name")
var name = dict.getSectionValue("Author","name")
var qq = dict.getSectionValue("Author","qq")
var email = dict.getSectionValue("Author","email")
echo pname & "\n" & name & "\n" & qq & "\n" & email
```

### Modifying a configuration file.

```nim
import parsecfg
var dict = loadConfig("config.ini")
dict.setSectionKey("Author","name","lhf")
dict.writeConfig("config.ini")
```


### Deleting a section key in a configuration file.

```nim
import parsecfg
var dict = loadConfig("config.ini")
dict.delSectionKey("Author","email")
dict.writeConfig("config.ini")
```

]#  # import {{{1

import streams
import strformat
import strutils
import tables

import py_configparser/common
import py_configparser/private/parse


type  # {{{1
  BasicInterpolation* = ref object of Interpolation
    defaults_additional: SectionTable

  ExtendedInterpolation* = ref object of Interpolation
    defaults_additional: SectionTable

  SafeConfigParser* = ConfigParser


proc initBasicInterpolation*(): BasicInterpolation =  # {{{1
    result = BasicInterpolation()


proc initExtendedInterpolation*(): ExtendedInterpolation =  # {{{1
    result = ExtendedInterpolation()


proc sections*(self: ConfigParser): seq[string] =  # {{{1
    for i in self.data.keys():
        result.add(i)


proc add_section*(self: var ConfigParser, section: string  # {{{1
                  ): SectionTable {.discardable.} =  # {{{1
    if self.data.hasKey(section):
        raise newException(DuplicateSectionError,
                           "section duplicated:" & section)
    result = newTable[string, string]()
    self.data.add(section, result)


proc defaults*(self: ConfigParser): SectionTable =  # {{{1
    return self.tbl_defaults


proc remove_section*(self: var ConfigParser, section: string): void =  # {{{1
    if not self.data.hasKey(section):
        raise newException(NoSectionError, "section not found:" & section)
    self.data.del(section)


proc remove_option*(self: var ConfigParser, section, option: string  # {{{1
                    ): bool {.discardable.} =  # {{{1
    if not self.data.hasKey(section):
        raise newException(NoSectionError, "section not found:" & section)
    if not self.data.hasKey(section):
        return false
    self.data[section].del(option)
    return true


proc read*(c: var ConfigParser, input: iterator(): string): void =  # {{{1
    c.parse(input)


proc read_file*(c: var ConfigParser, input: Stream, source = ""): void =  # {{{1
    iterator iter_lines(): string =
        var line = ""
        while input.readLine(line):
            yield line

    c.parse(iter_lines)


proc read*(c: var ConfigParser, input: string, encoding: string = "") =  # {{{1
    var fp = newFileStream(input, fmRead)
    defer: fp.close
    c.read_file(fp, input)


proc read_string*(c: var ConfigParser, input: string) =  # {{{1
    iterator iter_lines(): string =
        for line in input.splitLines():
            yield line

    c.read(iter_lines)


#[
proc writeConfig*(dict: Config, stream: Stream) =
  ## Writes the contents of the table to the specified stream
  ##
  ## **Note:** Comment statement will be ignored.
  for section, sectionData in dict.pairs():
    if section != "": ## Not general section
      if not allCharsInSet(section, SymChars): ## Non system character
        stream.writeLine("[\"" & section & "\"]")
      else:
        stream.writeLine("[" & section & "]")
    for key, value in sectionData.pairs():
      var kv, segmentChar: string
      if key.len > 1 and key[0] == '-' and key[1] == '-': ## If it is a command key
        segmentChar = ":"
        if not allCharsInSet(key[2..key.len()-1], SymChars):
          kv.add("--\"")
          kv.add(key[2..key.len()-1])
          kv.add("\"")
        else:
          kv = key
      else:
        segmentChar = "="
        kv = key
      if value != "": ## If the key is not empty
        if not allCharsInSet(value, SymChars):
          if find(value, '"') == -1:
            kv.add(segmentChar)
            kv.add("\"")
            kv.add(replace(value))
            kv.add("\"")
          else:
            kv.add(segmentChar)
            kv.add("\"\"\"")
            kv.add(replace(value))
            kv.add("\"\"\"")
        else:
          kv.add(segmentChar)
          kv.add(value)
      stream.writeLine(kv)
]#


proc do_interpolation(self: ConfigParser, section, value: string,  # {{{1
                      level: int): string =
    if isNil(self):
        return value
    if isNil(self.interpolation):
        return value
    return self.interpolation.run(self, section, value, level)


proc get_with_level*(self: ConfigParser, section, option: string,  # {{{1
                     level: int): tuple[s: string, f: bool] =
    var ret = ""
    var opt = self.optionxform.do_transform(option)

    # 2nd search in section.
    if self.data.hasKey(section):
        var tbl = self.data[section]
        if tbl.hasKey(opt):
            ret = tbl[opt]
            return (do_interpolation(self, section, ret, level), true)

    # 3rd search in default section.
    var tbl = self.data[""]
    if tbl.hasKey(opt):
        ret = tbl[opt]
        return (do_interpolation(self, section, ret, level), true)

    return ("", false)


proc get*(self: ConfigParser, section, option: string, raw = false,  # {{{1
          vars: TableRef[string, string] = nil, fallback: string = ""): string =
    var opt = self.optionxform.do_transform(option)
    if not isNil(vars):  # vars is 1st priority.
        if vars.hasKey(opt):
            var ret = vars[opt]
            return do_interpolation(self, section, ret, 1)

    var (ret, found) = self.get_with_level(section, option, 1)
    if found:
        return ret

    if len(fallback) < 1:  # finally go into fallback.
        raise newException(NoOptionError, "does not have option: " & opt)
    return do_interpolation(self, section, fallback, 1)


proc get*(self: SectionTable, option: string,  # {{{1
          vars: TableRef[string, string] = nil): string =  # {{{1
    var ret = ""
    var opt = do_transform(nil, option)
    if not self.hasKey(opt):
        raise newException(NoOptionError, "does not have option: " & opt)
    ret = self[opt]
    # ret = do_interpolation(nil, "", ret)  # not meaningful.
    return ret


proc get*(self: SectionTable, option, fallback: string): string =  # {{{1
    var ret = ""
    var opt = do_transform(nil, option)
    if not self.hasKey(opt):
        return fallback
    ret = self[opt]
    # ret = do_interpolation(nil, "", ret)  # not meaningful.
    return ret


proc getint*(self: ConfigParser, section, option: string, raw = false,  # {{{1
             vars: TableRef[string, string] = nil): int =
    var src = self.get(section, option, raw, vars)
    var ret = parseInt(src)
    return ret


proc getint*(self: ConfigParser, section, option: string,  # {{{1
             fallback: int, raw = false,
             vars: TableRef[string, string] = nil): int =
    var src = self.get(section, option, raw, vars, $fallback)
    var ret = parseInt(src)
    return ret


proc getint*(self: SectionTable, option: string): int =  # {{{1
    var ret = parseInt(self[option])
    return ret


proc getint*(self: SectionTable, option: string,  # {{{1
             fallback: int): int =  # {{{1
    if not self.hasKey(option):
        return fallback
    var ret = parseInt(self[option])
    return ret


proc getfloat*(self: ConfigParser, section, option: string, raw = false,  # {{{1
               vars: TableRef[string, string] = nil): float =
    var src = self.get(section, option, raw, vars)
    var ret = parseFloat(src)
    return ret


proc getfloat*(self: ConfigParser, section, option: string,  # {{{1
               fallback: float, raw = false,
               vars: TableRef[string, string] = nil): float =
    try:
        var src = self.get(section, option, raw, vars)
        var ret = parseFloat(src)
        return ret
    except NoOptionError as e:
        discard
    return fallback


proc getfloat*(self: SectionTable, option: string): float =  # {{{1
    var ret = parseFloat(self[option])
    return ret


proc getfloat*(self: SectionTable, option: string,  # {{{1
               fallback: float): float =
    if not self.hasKey(option):
        return fallback
    var ret = parseFloat(self[option])
    return ret


proc getboolean_chk(src: string, tbl: TableRef[string, bool]): bool =  # {{{1
    var pats_true, pats_false: seq[string]
    if isNil(tbl):
        pats_true = @["yes", "on", "true", "1"]
        pats_false = @["no", "off", "false", "0"]
    else:
        pats_true = @[]
        pats_false = @[]
        for k, v in tbl.pairs():
            if v:
                pats_true.add(k)
            else:
                pats_false.add(k)
    for pat in pats_true:
        if src == pat:
            return true
    for pat in pats_false:
        if src == pat:
            return false
    raise newException(ParsingError, ":" & src)


proc getboolean*(self: ConfigParser, section, option: string, raw = false,  # {{{1
                 vars: TableRef[string, string] = nil): bool =
    var src = self.get(section, option, raw, vars)
    return getboolean_chk(src, self.BOOLEAN_STATES)


proc getboolean*(self: ConfigParser, section, option: string,  # {{{1
                 fallback: bool, raw = false,
                 vars: TableRef[string, string] = nil): bool =
    try:
        var src = self.get(section, option, raw, vars)
        return getboolean_chk(src, self.BOOLEAN_STATES)
    except NoOptionError as e:
        discard
    return fallback


proc getboolean*(self: SectionTable, option: string): bool =  # {{{1
    var src = self[option]
    return getboolean_chk(src, nil)


proc getboolean*(self: SectionTable, option: string, fallback: bool  # {{{1
                 ): bool =
    if not self.hasKey(option):
        return fallback
    var src = self[option]
    return getboolean_chk(src, nil)


proc get*(self: SectionTable, option: string, fallback: bool): bool =  # {{{1
    return self.getboolean(option, fallback)


proc getlist_parse*(src: string): seq[string] =  # {{{1
    var ret: seq[string] = @[]
    for i in src.split(' '):
        if len(i) < 1:
            continue
        ret.add(i)
    return ret


proc getlist*(self: ConfigParser, section, option: string, raw = false,  # {{{1
              vars: TableRef[string, string] = nil,
              fallback: tuple[en: bool, val: seq[string]] = (false, @[])
              ): seq[string] =
    try:
        var src = self.get(section, option, raw, vars)
        return getlist_parse(src)
    except NoOptionError as e:
        if fallback.en:
            return fallback.val
        raise e


proc getlist*(self: SectionTable, option: string): seq[string] =  # {{{1
    var src = self[option]
    return getlist_parse(src)


proc `[]`*(self: ConfigParser, section: string): SectionTable =  # {{{1
    if not self.data.hasKey(section):
        raise newException(NoSectionError, section & " not found")
    return self.data[section]


proc `[]`*(self: SectionTable, option: string): string =  # {{{1
    return self[][option]


proc options*(self: ConfigParser, section: string): seq[string] =  # {{{1
    var ret: seq[string] = @[]
    for i in self.data[section].keys():
        ret.add(i)
    return ret


proc has_section*(self: ConfigParser, section: string): bool =  # {{{1
    return self.sections().contains(section)


proc set*(self: var ConfigParser, section, option, value: string  # {{{1
          ): void =
    if not self.has_section(section):
        raise newException(NoSectionError, "section not found: " & section)
    var tbl = self.data[section]
    var opt = self.optionxform.do_transform(option)
    if tbl.hasKey(opt):
        raise newException(DuplicateOptionError, "option duplicated: " &
                           section & "-" & opt)
    tbl[opt] = value


proc read_dict*(c: var ConfigParser, src: Table[string, SectionTable],  # {{{1
                source = ""): void =
    for section, tbl in src.pairs():
        if not c.has_section(section):
            c.add_section(section)
        for option, value in tbl.pairs():
            c.set(section, option, value)


proc read_dict*(c: var ConfigParser, src: ConfigParser,  # {{{1
                source = ""): void =
    c.read_dict(src, source)


proc has_option*(self: ConfigParser, section, option: string): bool =  # {{{1
    if not self.data.hasKey(section):
        return false
    var opt = self.optionxform.do_transform(option)
    return self.data[section].hasKey(opt)


proc resolve_interpolation(self: BasicInterpolation, cfg: ConfigParser,  # {{{1
                           section, value: string, level: int): string =
    if level > cfg.MAX_INTERPOLATION_DEPTH:
        raise newException(InterpolationDepthError, "for " & value)

    # search value from section, defaults, interpolate's defaults
    var ret = value
    if cfg.has_option(section, ret):
        var f_dmy: bool
        (ret, f_dmy) = cfg.get_with_level(section, ret, level + 1)
    elif not isNil(self.defaults_additional) and
             self.defaults_additional.hasKey(ret):
        ret = self.defaults_additional[ret]
        if ret.contains('%'):
            return self.run(cfg, section, ret, level + 1)
    else:
        raise newException(InterpolationMissingOptionError,
                           "not found:" & value)

    return ret


method run(self: BasicInterpolation, cfg: ConfigParser,  # {{{1
           section, value: string, level: int): string =
    proc run_in_else(ch: char, dst: var seq[tuple[s: string, f: bool]]): bool =
        case ch:
        of '%':
            return true
        else:
            dst[^ 1].s &= $ch
        return false

    proc run_after_prefix(ch: char, dst: var seq[tuple[s: string, f: bool]]
                          ): bool =
        case ch:
        of '(':
            dst.add((s: "", f: true))
        else:  # maybe `of '%':`
            dst[^ 1].s &= $ch
        return false

    proc run_in_var(ch: char, dst: var seq[tuple[s: string, f: bool]]): void =
        case ch:
        of ')':
            dst.add((s: "", f: false))
        else:
            dst[^ 1].s &= $ch

    var ret: seq[tuple[s: string, f: bool]] = @[("", false)]
    var f_prefix = false
    for i in 0..len(value) - 1:
        var ch = value[i]
        if f_prefix:
            f_prefix = run_after_prefix(ch, ret)
        elif ret[^ 1].f:
            run_in_var(ch, ret)
        else:
            f_prefix = run_in_else(ch, ret)

    result = ""
    for part in ret:
        if part.f:
            result &= self.resolve_interpolation(cfg, section, part.s, level)
        else:
            result &= part.s


proc resolve_interpolation(self: ExtendedInterpolation, cfg: ConfigParser,  # {{{1
                           section, value: string, level: int): string =
    if level > cfg.MAX_INTERPOLATION_DEPTH:
        raise newException(InterpolationDepthError, "for " & value)

    # search value from section, defaults, interpolate's defaults
    var (section_name, ret) = (section, value)
    if value.contains(':'):
        var seq = value.split(':')
        section_name = seq[0]
        ret = join(seq[1..^1], ":")

    if cfg.has_option(section_name, ret):
        var f_dmy: bool
        (ret, f_dmy) = cfg.get_with_level(section_name, ret, level + 1)
    elif not isNil(self.defaults_additional) and
             self.defaults_additional.hasKey(ret):
        ret = self.defaults_additional[ret]
        if ret.contains('$'):
            return self.run(cfg, section_name, ret, level + 1)
    else:
        raise newException(InterpolationMissingOptionError,
                           "not found:" & value)

    return ret


method run(self: ExtendedInterpolation, cfg: ConfigParser,  # {{{1
           section, value: string, level: int): string =
    proc run_in_else(ch: char, dst: var seq[tuple[s: string, f: bool]]): bool =
        case ch:
        of '$':
            return true
        else:
            dst[^ 1].s &= $ch
        return false

    proc run_after_prefix(ch: char, dst: var seq[tuple[s: string, f: bool]]
                          ): bool =
        case ch:
        of '{':
            dst.add((s: "", f: true))
        else:  # maybe `of '%':`
            dst[^ 1].s &= $ch
        return false

    proc run_in_var(ch: char, dst: var seq[tuple[s: string, f: bool]]): void =
        case ch:
        of '}':
            dst.add((s: "", f: false))
        else:
            dst[^ 1].s &= $ch

    var ret: seq[tuple[s: string, f: bool]] = @[("", false)]
    var f_prefix = false
    for i in 0..len(value) - 1:
        var ch = value[i]
        if f_prefix:
            f_prefix = run_after_prefix(ch, ret)
        elif ret[^ 1].f:
            run_in_var(ch, ret)
        else:
            f_prefix = run_in_else(ch, ret)

    result = ""
    for part in ret:
        if part.f:
            result &= self.resolve_interpolation(cfg, section, part.s, level)
        else:
            result &= part.s


proc items*(self: ConfigParser, section: string, raw: bool = false,   # {{{1
            vars: TableRef[string, string] = nil
            ): seq[tuple[option: string, value: string]] =
    if not self.data.hasKey(section):
        raise newException(NoSectionError, "section not found: " & section)
    for k, v in self.data[section].pairs():
        result.add((k, v))


proc items*(self: ConfigParser, raw: bool = false,  # {{{1
            vars: TableRef[string, string] = nil
            ): seq[tuple[section: string, options: SectionTable]] =
    for k, v in self.data.pairs():
        result.add((k, v))


proc items*(self: SectionTable, raw: bool = false  # {{{1
            ): seq[tuple[option, value: string]] =
    for k, v in self.pairs():
        result.add((k, v))


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
