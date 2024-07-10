#[
`configparser`
===============================================================================
yet another configuration file parser to able python behaviors.

## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

## Example

```nim
import configparser

var cfg = initConfigParser()
cfg.read_string("""
    [Package]
    name = "hello"
    --threads:on
    [Author]
    name = "lihf8515"
    qq = "10214028"
    email = "lihaifeng@wxm.com"
    """)
echo cfg.get("some", "option")
```

]#  # import {{{1

import streams
import strformat
import strutils
import tables

import configparser/common
import configparser/private/parse
import configparser/private/dump


# exports {{{1
# import `configparser/common` to use all symbols
export common.ConfigParser
export common.initConfigParser
export common.NoOptionError
export common.NoSectionError
export common.DuplicateOptionError
export common.DuplicateSectionError
export common.InterpolationDepthError
export common.InterpolationMissingOptionError

export dump.write


type  # {{{1
  BasicInterpolation* = ref object of Interpolation
    defaults_additional: SectionTable

  ExtendedInterpolation* = ref object of Interpolation
    defaults_additional: SectionTable

  SafeConfigParser* = ConfigParser


# api for the SectionTable {{{1
proc hasKey*(self: SectionTable, option: string): bool {.gcsafe.}
proc del*(self: var SectionTable, option: string): bool {.discardable, gcsafe.}
proc `[]`*(self: SectionTable, option: string): string {.gcsafe.}


proc initBasicInterpolation*(): BasicInterpolation =  # {{{1
    result = BasicInterpolation()


proc initExtendedInterpolation*(): ExtendedInterpolation =  # {{{1
    result = ExtendedInterpolation()


proc sections*(self: ConfigParser): seq[string] =  # {{{1
    for i in self.data.keys():
        if i == self.secname_default:
            continue
        result.add(i)


proc contains*(self: SectionTable, option: string): bool =  # {{{1
    return self.data.hasKey(option)


proc `[]=`*(self: SectionTable, option: string, value: string): void =  # {{{1
    self.data[option] = value


proc add_section*(self: var ConfigParser, section: string  # {{{1
                  ): SectionTable {.discardable.} =
    if self.data.hasKey(section):
        raise newException(DuplicateSectionError,
                           "section duplicated:" & section)
    var ret = SectionTable(name: section)
    ret.parser = self
    ret.data = newTable[string, string]()
    self.data[section] = ret


proc defaults*(self: ConfigParser): SectionTable =  # {{{1
    return self.tbl_defaults


proc remove_section*(self: var ConfigParser, section: string): void =  # {{{1
    if not self.data.hasKey(section):
        raise newException(NoSectionError, fmt"section '{section}' not found.")
    if section == self.secname_default:
        raise newException(NoSectionError, fmt"section '{section}' not found.")
    self.data.del(section)


proc remove_option*(self: var ConfigParser, section, option: string  # {{{1
                    ): bool {.discardable.} =
    if not self.data.hasKey(section):
        raise newException(NoSectionError, fmt"section '{section}' not found.")
    var sec = self.data[section]
    if not sec.hasKey(option):
        raise newException(NoOptionError,
                           fmt"option '{section}-{option}' not found.")
    return sec.del(option)


proc del*(self: var SectionTable, option: string  # {{{1
          ): bool {.discardable.} =
    if not self.hasKey(option):
        raise newException(NoOptionError,
                           fmt"option '{self.name}-{option}' not found.")
    self.data.del(option)
    return true


proc read*(c: var ConfigParser, input: iterator(): string {.gcsafe.}): void =
    if isNil(c.data):
        c.clear()
    c.parse(input)


proc read_file*(c: var ConfigParser, input: Stream, source = ""): void =  # {{{1
    iterator iter_lines(): string =
        var line = ""
        while input.readLine(line):
            yield line

    if isNil(c.data):
        c.clear()
    c.parse(iter_lines)


proc read*(c: var ConfigParser, input: string, encoding: string = "") =  # {{{1
    var fp = newFileStream(input, fmRead)
    if isNil(fp):
        raise newException(IOError, "can't open file: " & input)
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
    var value = value.replace("\n\t", " ")
    if isNil(self):
        return value
    if isNil(self.interpolation):
        return value
    return self.interpolation.run(self, section, value, level)


proc get_with_level(self: ConfigParser, section, option: string,  # {{{1
                    level: int): tuple[s: string, err: int] =
    var ret = ""
    var opt = self.optionxform.do_transform(option)

    # 2nd search in section.
    var err = 0
    if self.data.hasKey(section):
        var tbl = self.data[section]
        if tbl.hasKey(opt):
            ret = tbl[opt]
            return (do_interpolation(self, section, ret, level), 0)
        err = err + 1
    else:
        err = err + 4

    # 3rd search in default section.
    var tbl = self.data[self.secname_default]
    if tbl.hasKey(opt):
        ret = tbl[opt]
        return (do_interpolation(self, section, ret, level), 0)
    err = err + 2
    return ("", err)


proc get_core(self: ConfigParser, section, option, fallback: string,  # {{{1
              raw, f_fallback: bool, vars: TableRef[string, string]): string =
    var (f_ret, ret, err) = (false, "", 0)
    var opt = self.optionxform.do_transform(option)
    if not isNil(vars):  # vars is 1st priority.
        if vars.hasKey(opt):
            (f_ret, ret) = (true, vars[opt])
    if not f_ret:
        (ret, err) = self.get_with_level(section, option, 1)
        if err == 0:
            return ret
    if (not f_ret) and f_fallback:
        (f_ret, ret) = (true, fallback)

    if f_ret:
        return do_interpolation(self, section, ret, 1)

    if (err and 4) != 0:
        raise newException(NoSectionError,
                           fmt"does not have section: '{section}'")
    raise newException(NoOptionError, "does not have option: " & opt)



proc get*(self: ConfigParser, section, option, fallback: string,  # {{{1
          raw = false, vars: TableRef[string, string] = nil): string =
    return self.get_core(section, option, fallback, raw, true, vars)


proc get*(self: ConfigParser, section, option: string, raw = false,  # {{{1
          vars: TableRef[string, string] = nil): string =
    return self.get_core(section, option, "", raw, false, vars)


proc get*(self: SectionTable, option: string,  # {{{1
          vars: TableRef[string, string] = nil): string =
    var ret = ""
    var opt = do_transform(nil, option)
    if not isNil(vars) and vars.hasKey(opt):    # 1st, vars.
        ret = vars[opt]
    elif self.hasKey(opt):  # 2nd, section
        ret = self[opt]
    else:
        raise newException(NoOptionError, "does not have option: " & opt)
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
    var src = self.get(section, option, $fallback, raw, vars)
    var ret = parseInt(src)
    return ret


proc getint*(self: SectionTable, option: string): int =  # {{{1
    var ret = parseInt(self[option])
    return ret


proc getint*(self: SectionTable, option: string,  # {{{1
             fallback: int): int =
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
    except NoOptionError:
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
    except NoOptionError:
        discard
    except NoSectionError:
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
              vars: TableRef[string, string] = nil): seq[string] =
    var src = self.get(section, option, raw, vars)
    return getlist_parse(src)


proc getlist*(self: ConfigParser, section, option: string, raw = false,  # {{{1
              fallback: seq[string],
              vars: TableRef[string, string] = nil): seq[string] =
    try:
        var src = self.get(section, option, raw, vars)
        return getlist_parse(src)
    except NoOptionError:
        discard
    return fallback


proc getlist*(self: SectionTable, option: string): seq[string] =  # {{{1
    var src = self[option]
    return getlist_parse(src)


proc `[]`*(self: ConfigParser, section: string): var SectionTable =  # {{{1
    if not self.data.hasKey(section):
        raise newException(NoSectionError, section & " not found")
    return self.data[section]


proc `[]`*(self: SectionTable, option: string): string =  # {{{1
    if not self.data.hasKey(option):
        raise newException(NoOptionError, "does not have option: " & option)
    var ret = self.data[option]
    ret = ret.replace("\n\t", " ")  # TODO(shimoda): fix it, make function.
    return ret


proc options*(self: ConfigParser, section: string): seq[string] =  # {{{1
    var ret: seq[string] = @[]
    for i in self.data[section].data.keys():
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
    tbl.data[opt] = value


proc read_dict*(c: var ConfigParser,  # {{{1
                src: Table[string, Table[string, string]]): void =
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


proc hasKey*(self: SectionTable, option: string): bool =  # {{{1
    return self.data.hasKey(option)


proc resolve_interpolation(self: BasicInterpolation, cfg: ConfigParser,  # {{{1
                           section, value: string, level: int): string =
    if level > cfg.MAX_INTERPOLATION_DEPTH:
        raise newException(InterpolationDepthError, "for " & value)

    # search value from section, defaults, interpolate's defaults
    var ret = value
    if cfg.has_option(section, ret):
        var err: int
        (ret, err) = cfg.get_with_level(section, ret, level + 1)
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
           section, value: string, level: int): string {.gcsafe.} =
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
        var err: int
        (ret, err) = cfg.get_with_level(section_name, ret, level + 1)
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


proc items*(self: SectionTable, raw: bool = false  # {{{1
            ): seq[tuple[option, value: string]] =
    for k, v in self.data.pairs():
        result.add((k, v))


proc items*(self: ConfigParser, section: string, raw: bool = false,   # {{{1
            vars: TableRef[string, string] = nil
            ): seq[tuple[option: string, value: string]] =
    if not self.data.hasKey(section):
        raise newException(NoSectionError, "section not found: " & section)
    # TODO(shimoda): behavior of vars???
    var sec = self.data[section]
    return sec.items()


proc items*(self: ConfigParser, raw: bool = false,  # {{{1
            vars: TableRef[string, string] = nil
            ): seq[tuple[section: string, options: SectionTable]] =
    for k in self.sections():
        var v = self[k]
        result.add((k, v))


# end of file {{{1
# vi: ft=nim:et:ts=4:nowrap
