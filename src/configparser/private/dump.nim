#[
Copyright (c) 2021, shimoda as kuri65536 _dot_ hot mail _dot_ com
                       ( email address: convert _dot_ to . and joint string )

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at https://mozilla.org/MPL/2.0/.
]#
import algorithm
import streams
import strformat
import system
import tables

import ../common


proc write_one_pair(output: Stream, option, value: string,  # {{{1
                    delimiter: string): void =
    output.writeLine(fmt"{option}{delimiter}{value}")


proc write*(self: ConfigParser, output: Stream,  # {{{1
            space_around_delimiters: bool = false): void =
    var delimiter = self.delimiters[0]
    if space_around_delimiters:
        delimiter = " " & delimiter & " "

    var sections: seq[string] = @[]
    for section_name in self.data.keys():
        sections.add(section_name)
    sections.sort(system.cmp)

    for section_name in sections:
        output.writeLine(fmt"[{section_name}]")
        let section = self.data[section_name]
        for option_name in section.data.keys():
            let value = section.data[option_name]
            write_one_pair(output, option_name, value, delimiter)
        output.writeLine("")
    output.setPosition(0)

# end of file {{{1
# vi: ft=nim:et:ts=4:fdm=marker:nowrap
