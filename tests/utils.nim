#[

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.

]#
import strutils


type
  Config = ref object of RootObj  # {{{1
    allow_no_value*: bool
    comment_prefixes*: seq[string]
    default_section*: string
    delimiters*: seq[string]
    strict*: bool

let cfg* = Config(allow_no_value: false,
                  comment_prefixes: @["#", ";"],
                  default_section: "DEFAULT",
                  delimiters: @["=", ":"],
                  # delimiters: @["=", ";"],
                  strict: true)


proc conv_delim*(src: openArray[string],
                 delims: seq[string] = @[],
                 cmtpfx: seq[string] = @[],
                 ): string =  # {{{1
    var delims = delims
    if len(delims) < 1:
        delims = cfg.delimiters
    var cmtpfx = cmtpfx
    if len(cmtpfx) < 1:
        cmtpfx = cfg.comment_prefixes

    var ret = join(src, "\n")
    ret = ret.replace("{d0}", delims[0])
    if len(delims) >= 2:
        ret = ret.replace("{d1}", delims[1])
    ret = ret.replace("{c0}", cmtpfx[0])
    if len(cmtpfx) >= 2:
        ret = ret.replace("{c1}", cmtpfx[1])
    return ret



