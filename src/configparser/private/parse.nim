#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.
]#  # import {{{1

import streams
import strformat
import strutils
import tables

import ../common


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

  ParserStatus* = ref object of RootObj
    cur_state: ParseResult
    cur_section: SectionTable
    cur_section_name: string


proc sections_local(self: ConfigParser): seq[string] =  # {{{1
    for i in self.data.keys():
        result.add(i)


proc add_section(self: var ConfigParser, section: string  # {{{1
                 ): SectionTable {.discardable.} =
    if section not_in self.sections_local():
        result = SectionTable(name: section)
        result.data = newTable[string, string]()
        self.data.add(section, result)
        return result

    if section == self.secname_default:
        return self.data[section]

    if not self.f_allow_dups:
        raise newException(DuplicateSectionError,
                           "section duplicated:" & section)
    return self.data[section]


proc add_option(self: var SectionTable, opt, val: string  # {{{1
                ): void =
    if self.data.hasKey(opt):
        raise newException(DuplicateOptionError,
                           "option duplicated:" & opt)
    self.data.add(opt, val)


proc defaults*(self: ConfigParser): SectionTable =  # {{{1
    return self.tbl_defaults


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


proc parse_finish(c: ParserStatus, line: string): ParseResult =  # {{{1
    case c.cur_state:
    of in_val:
        return ParseResult.in_val
    else:
        discard
    return ParseResult.in_empty


proc parse_section_line(self: ParserStatus, c: var ConfigParser,   # {{{1
                        line: string): ParseResult =
    var left = line.strip(leading = true)
    if not left.startsWith("["):
        return ParseResult.in_empty
    left = left[1..^1]
    var right = remove_comment(left, space = true)
    if not right.endswith("]"):
        return ParseResult.in_error_section
    right = right[0..^2]

    var sec = right.strip(chars = {' '})
    self.cur_section_name = sec
    self.cur_section = c.add_section(sec)
    return ParseResult.section


proc parse_option_value(self: ParserStatus,  # {{{1
                        c: var ConfigParser, line: string
                        ): tuple[st: ParseResult, opt, val: string] =
    let splitter_opt_val = {'=', ':'}
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
                discard self.parse_finish(opt)
                var ret = self.parse_section_line(c, line[n..^1])
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
    if self.cur_section.data.hasKey(opt):
        if not c.f_allow_dups:
            raise newException(DuplicateOptionError,
                               "duplicated option: " & opt)
        return (opt_and_dup, opt, val)
    val = val.strip()
    return (opt_and_val, opt, val)


proc parse*(c: var ConfigParser, input: iterator(): string): void =  # {{{1
    if isNil(c.tbl_defaults):
        var sec = SectionTable(name: c.secname_default)
        sec.data = newTable[string, string]()
        c.tbl_defaults = sec
    if isNil(c.data):
        c.data = newTable[string, SectionTable]()

    var stat = ParserStatus()
    stat.cur_section = c.tbl_defaults
    stat.cur_section_name = c.secname_default
    c.data.add(c.secname_default, stat.cur_section)

    var line, cur_opt, cur_val: string
    var cur = ParseResult.in_empty
    for line in input():
        var (st, opt, val) = stat.parse_option_value(c, line)
        case st:
        of opt_and_val:
            (cur, cur_opt, cur_val) = (ParseResult.in_val, opt, val)
            stat.cur_section.add_option(opt, val)
        of opt_and_dup:
            cur = ParseResult.in_empty
        of opt_or_invalid:
            val = val.strip()
            if cur != ParseResult.in_val:
                discard
            elif len(val) > 0 and stat.cur_section.data.hasKey(cur_opt):
                stat.cur_section.data[cur_opt] &= "\n\t" & val
            else:
                cur = ParseResult.in_empty
        else:
            discard


# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
