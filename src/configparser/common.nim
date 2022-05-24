#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.
]#  # import {{{1
import strutils
import system
import tables


type  # {{{1
  Error = object of ValueError
  DuplicateSectionError* = object of Error
  DuplicateOptionError* = object of Error
  ParsingError* = object of Error
  MissingSectionHeaderError* = object of ValueError
  NoSectionError* = object of Error
  NoOptionError* = object of Error
  InterpolationDepthError* = object of Error
  InterpolationMissingOptionError* = object of Error

  SectionTable* = ref object of RootObj
    name*: string
    parser*: ConfigParser
    data*: TableRef[string, string]

  Interpolation* = ref object of RootObj
    discard

  ConfigParser* = ref object of RootObj
    data*: TableRef[string, SectionTable]
    tbl_defaults*: SectionTable
    secname_default*: string
    delimiters*: seq[string]
    comment_prefixes*: seq[string]
    inline_comment_prefixes*: seq[string]
    optionxform*: proc(src: string): string {.gcsafe.}
    interpolation*: Interpolation
    BOOLEAN_STATES*: TableRef[string, bool]
    MAX_INTERPOLATION_DEPTH*: int
    f_allow_dups*: bool


proc clear*(cf: var ConfigParser,  # {{{1
            delimiters: seq[string] = @["=", ":"],
            comment_prefixes: seq[string] = @["#", ";"],
            inline_comment_prefixes: seq[string] = @[";"],
            default_section = "DEFAULT",
            interpolation: Interpolation = nil
            ): ConfigParser {.discardable.} =
    cf.data = newTable[string, SectionTable]()
    cf.secname_default = default_section
    cf.MAX_INTERPOLATION_DEPTH = 10

    cf.delimiters = delimiters
    cf.comment_prefixes = comment_prefixes
    cf.inline_comment_prefixes = inline_comment_prefixes
    cf.interpolation = interpolation
    return cf


proc initConfigParser*(delimiters = @["=", ":"],  # {{{1
                       comment_prefixes = @["#", ";"],
                       inline_comment_prefixes = @[";"],
                       default_section = "DEFAULT",
                       interpolation: Interpolation = nil): ConfigParser =
    var ret = ConfigParser()
    return ret.clear(delimiters,
                     comment_prefixes, inline_comment_prefixes,
                     default_section, interpolation)


proc do_transform*(self: proc(src: string): string, src: string
                   ): string = # {{{1
    result = src.toLower()
    if isNil(self):
        return result
    return self(src)


method run*(self: Interpolation, cfg: ConfigParser,  # {{{1
            section, value: string, level: int
            ): string {.base, gcsafe, locks: "unknown".} =
    return value


# vi: ft=nim:et:ts=4:fdm=marker:nowrap
