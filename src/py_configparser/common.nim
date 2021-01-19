#[
## license <!-- {{{1 -->
Copyright (c) 2020, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.
]#  # import {{{1
import strutils
import tables


type  # {{{1
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

  ConfigParser* = ref object of RootObj
    data*: TableRef[string, SectionTable]
    tbl_defaults*: SectionTable
    secname_default*: string
    comment_prefixes*: seq[string]
    inline_comment_prefixes*: seq[string]
    optionxform*: ref proc(src: string): string
    interpolation*: Interpolation
    BOOLEAN_STATES*: TableRef[string, bool]
    MAX_INTERPOLATION_DEPTH*: int
    f_allow_dups*: bool


proc initConfigParser*(comment_prefixes = @["#", ";"],  # {{{1
                       inline_comment_prefixes = @[";"],
                       interpolation: Interpolation = nil): ConfigParser =
    return ConfigParser(
        data: newTable[string, SectionTable](),
        comment_prefixes: comment_prefixes,
        inline_comment_prefixes: inline_comment_prefixes,
        secname_default: "",
        MAX_INTERPOLATION_DEPTH: 10,
        interpolation: interpolation)


proc do_transform*(self: ref proc(src: string): string, src: string): string =  # {{{1
    result = src.toLower()
    if isNil(self):
        return result
    return self[](src)


method run*(self: Interpolation, cfg: ConfigParser,  # {{{1
            section, value: string, level: int): string {.base.} =
    return value


# vi: ft=nim:et:ts=4:fdm=marker:nowrap
