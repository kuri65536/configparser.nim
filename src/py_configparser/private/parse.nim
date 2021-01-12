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


type  # {{{1
  ParseResult = enum ## enumeration of all events that may occur when parsing
    opt_and_val,        ## end of file reached
    opt_and_dup,
    opt_or_invalid,
    in_opt,
    in_empty,
    in_val,
    section,            ## a ``[section]`` has been parsed
    in_error_section,   ## an error occurred during parsing

  Error = object of Exception
  DuplicateSectionError* = object of Error
  DuplicateOptionError* = object of Error
  ParsingError* = object of Error
  MissingSectionHeaderError* = object of ValueError
  NoSectionError* = object of Error
  NoOptionError* = object of Error
  InterpolationDepthError* = object of Error
  InterpolationMissingOptionError* = object of Error

  SectionTable* = TableRef[string, string]

  Interpolation* = ref object of RootObj
    discard

  BasicInterpolation* = ref object of Interpolation
    defaults_additional: SectionTable

  ExtendedInterpolation* = ref object of Interpolation
    defaults_additional: SectionTable

  ConfigParser* = ref object of RootObj
    cur_state: ParseResult
    cur_section: SectionTable
    cur_section_name: string

    data: TableRef[string, SectionTable]
    tbl_defaults: SectionTable
    comment_prefixes: seq[string]
    inline_comment_prefixes: seq[string]
    optionxform*: ref proc(src: string): string
    interpolation: Interpolation
    BOOLEAN_STATES*: TableRef[string, bool]
    MAX_INTERPOLATION_DEPTH*: int

  SafeConfigParser* = ConfigParser


method run(self: Interpolation, cfg: ConfigParser,  # {{{1
           section, value: string, level: int): string {.base.} =
    return value


proc do_transform(self: ref proc(src: string): string, src: string): string =  # {{{1
    result = src.toLower()
    if isNil(self):
        return result
    return self[](src)


proc initBasicInterpolation*(): BasicInterpolation =  # {{{1
    result = BasicInterpolation()


proc initExtendedInterpolation*(): ExtendedInterpolation =  # {{{1
    result = ExtendedInterpolation()


proc initConfigParser*(comment_prefixes = @["#", ";"],  # {{{1
                       inline_comment_prefixes = @[";"],
                       interpolation: Interpolation = nil): ConfigParser =
    return ConfigParser(
        data: newTable[string, SectionTable](),
        comment_prefixes: comment_prefixes,
        inline_comment_prefixes: inline_comment_prefixes,
        MAX_INTERPOLATION_DEPTH: 10,
        interpolation: interpolation)


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


proc is_match(patterns: seq[string], n: int, line: string, f_space: bool  # {{{1
              ): bool =
    if not f_space:
        return false
    var blks: seq[string] = @[]
    var ch_cur = line[n]
    for ch in patterns:
        if len(ch) > 1:
            blks.add(ch)
            continue
        if ch[0] == ch_cur:
            return true
    if len(blks) < 1:
        return false
    for blk in blks:
        var m = n + len(blk) - 1
        if m >= len(line):
            continue
        var blk_cur = line[n..m]
        if blk_cur == blk:
            return true
    return false


proc is_comment(self: ConfigParser, n: int, line: string, f_space: bool  # {{{1
                ): bool =
    is_match(self.inline_comment_prefixes, n, line, f_space)


proc is_heading_comment(self: ConfigParser, line: string): int =  # {{{1
    var whitespaces = " \t"
    for i in 0..len(line) - 1:
        var ch = line[i]
        if whitespaces.contains(ch):
            continue
        if is_match(self.comment_prefixes, i, line, true):
            return -2
        return i
    return -1


proc remove_comment(src: string, space: bool): string =  # {{{1
    var ret = ""
    var f_quote = false
    for i in src:
        if i == '#':
            break
        if f_quote:
            if i == '"':
                f_quote = false
        else:
            if i == '"':
                f_quote = true
        ret &= $i
    if space:
        ret = ret.strip()
    return ret


proc parse_finish(c: var ConfigParser, line: string): ParseResult =  # {{{1
    case c.cur_state:
    of in_val:
        return ParseResult.in_val
    else:
        discard
    return ParseResult.in_empty


proc parse_section_line(c: var ConfigParser, line: string): ParseResult =  # {{{1
    var left = line.strip(leading = true)
    if not left.startsWith("["):
        return ParseResult.in_empty
    left = left[1..^1]
    var right = remove_comment(left, space = true)
    if not right.endswith("]"):
        return ParseResult.in_error_section
    right = right[0..^2]

    var sec = right.strip()
    c.cur_section_name = sec
    if sec not_in c.sections():
        c.cur_section = c.add_section(sec)
    else:
        c.cur_section = c.data[sec]
    return ParseResult.section


proc parse_option_value(c: var ConfigParser, line: string  # {{{1
                        ): tuple[st: ParseResult, opt, val: string] =
    let splitter_opt_val = "=:"
    var f_opt = true
    var f_space = false
    var opt, val: string

    var n_start = c.is_heading_comment(line)
    if n_start < 0:
        return (in_empty, "", "")

    for n in n_start..len(line) - 1:
        var i = line[n]
        if f_opt:
            if c.is_comment(n, line, true):
                break
            if splitter_opt_val.contains(i):
                f_opt = false
                opt = opt.strip()
                continue
            if i == '[':
                discard c.parse_finish(opt)
                var ret = c.parse_section_line(line[n..^1])
                return (ret, "", "")
            opt &= $i
        else:
            var f = f_space
            f_space = (i == ' ')
            if c.is_comment(n, line, f):
                break
            val &= $i
    if f_opt:
        return (opt_or_invalid, "", opt)

    opt = c.optionxform.do_transform(opt)
    if c.cur_section.hasKey(opt):
        return (opt_and_dup, opt, val)
    val = val.strip()
    return (opt_and_val, opt, val)


proc read*(c: var ConfigParser, input: iterator(): string): void =  # {{{1
    if isNil(c.tbl_defaults):
        c.tbl_defaults = newTable[string, string]()

    c.data = newTable[string, SectionTable]()
    c.cur_section = newTable[string, string]()
    c.cur_section_name = ""
    c.data.add("", c.cur_section)

    var line, cur_opt, cur_val: string
    var cur = ParseResult.in_empty
    for line in input():
        var (st, opt, val) = c.parse_option_value(line)
        case st:
        of opt_and_val:
            (cur, cur_opt, cur_val) = (ParseResult.in_val, opt, val)
            c.cur_section.add(opt, val)
        of opt_and_dup:
            cur = ParseResult.in_empty
        of opt_or_invalid:
            val = val.strip()
            if cur != ParseResult.in_val:
                discard
            elif len(val) > 0 and c.cur_section.hasKey(cur_opt):
                c.cur_section[cur_opt] &= " " & val
            else:
                cur = ParseResult.in_empty
        else:
            discard


proc read_file*(c: var ConfigParser, input: Stream, source = ""): void =  # {{{1
    iterator iter_lines(): string =
        var line = ""
        while input.readLine(line):
            yield line

    c.read(iter_lines)


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
