#
#
#            Nim's Runtime Library
#        (c) Copyright 2010 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## The ``parsecfg`` module implements a high performance configuration file
## parser. The configuration file's syntax is similar to the Windows ``.ini``
## format, but much more powerful, as it is not a line based parser. String
## literals, raw string literals and triple quoted string literals are supported
## as in the Nim programming language.

## This is an example of how a configuration file may look like:
##
## .. include:: ../../doc/mytest.cfg
##     :literal:
##

##[ Here is an example of how to use the configuration file parser:

.. code-block:: nim

    import
      os, parsecfg, strutils, streams

    var f = newFileStream(paramStr(1), fmRead)
    if f != nil:
      var p: CfgParser
      open(p, f, paramStr(1))
      while true:
        var e = next(p)
        case e.kind
        of cfgEof: break
        of cfgSectionStart:   ## a ``[section]`` has been parsed
          echo("new section: " & e.section)
        of cfgKeyValuePair:
          echo("key-value-pair: " & e.key & ": " & e.value)
        of cfgOption:
          echo("command: " & e.key & ": " & e.value)
        of cfgError:
          echo(e.msg)
      close(p)
    else:
      echo("cannot open: " & paramStr(1))

]##

## Examples
## --------
##
## This is an example of a configuration file.
##
## ::
##
##     charset = "utf-8"
##     [Package]
##     name = "hello"
##     --threads:on
##     [Author]
##     name = "lihf8515"
##     qq = "10214028"
##     email = "lihaifeng@wxm.com"
##
## Creating a configuration file.
## ==============================
## .. code-block:: nim
##
##     import parsecfg
##     var dict=newConfig()
##     dict.setSectionKey("","charset","utf-8")
##     dict.setSectionKey("Package","name","hello")
##     dict.setSectionKey("Package","--threads","on")
##     dict.setSectionKey("Author","name","lihf8515")
##     dict.setSectionKey("Author","qq","10214028")
##     dict.setSectionKey("Author","email","lihaifeng@wxm.com")
##     dict.writeConfig("config.ini")
##
## Reading a configuration file.
## =============================
## .. code-block:: nim
##
##     import parsecfg
##     var dict = loadConfig("config.ini")
##     var charset = dict.getSectionValue("","charset")
##     var threads = dict.getSectionValue("Package","--threads")
##     var pname = dict.getSectionValue("Package","name")
##     var name = dict.getSectionValue("Author","name")
##     var qq = dict.getSectionValue("Author","qq")
##     var email = dict.getSectionValue("Author","email")
##     echo pname & "\n" & name & "\n" & qq & "\n" & email
##
## Modifying a configuration file.
## ===============================
## .. code-block:: nim
##
##     import parsecfg
##     var dict = loadConfig("config.ini")
##     dict.setSectionKey("Author","name","lhf")
##     dict.writeConfig("config.ini")
##
## Deleting a section key in a configuration file.
## ===============================================
## .. code-block:: nim
##
##     import parsecfg
##     var dict = loadConfig("config.ini")
##     dict.delSectionKey("Author","email")
##     dict.writeConfig("config.ini")

import
  hashes, strutils, lexbase, streams, tables

import strformat

include "system/inclrtl"

type
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

  #[
  CfgEvent* = object of RootObj ## describes a parsing event
    case kind*: CfgEventKind    ## the kind of the event
    of cfgEof: nil
    of cfgSectionStart:
      section*: string           ## `section` contains the name of the
                                 ## parsed section start (syntax: ``[section]``)
    of cfgKeyValuePair, cfgOption:
      key*, value*: string       ## contains the (key, value) pair if an option
                                 ## of the form ``--key: value`` or an ordinary
                                 ## ``key= value`` pair has been parsed.
                                 ## ``value==""`` if it was not specified in the
                                 ## configuration file.
    of cfgError:                 ## the parser encountered an error: `msg`
      msg*: string               ## contains the error message. No exceptions
                                 ## are thrown if a parse error occurs.
  ]#

  TokKind = enum
    tkInvalid, tkEof,
    tkSymbol, tkEquals, tkColon, tkBracketLe, tkBracketRi, tkDashDash
  Token = object             # a token
    kind: TokKind            # the type of the token
    literal: string          # the parsed (string) literal

  SectionTable* = TableRef[string, string]

  ConfigParser* = ref object of RootObj
    cur_state: ParseResult
    cur_section: SectionTable
    cur_section_name: string
    cur_opt, cur_val: string

    data: TableRef[string, SectionTable]
    tbl_defaults: SectionTable
    comment_prefixes: seq[string]
    inline_comment_prefixes: seq[string]
    optionxform*: ref proc(src: string): string

  SafeConfigParser* = ConfigParser


# implementation

const
  SymChars = {'a'..'z', 'A'..'Z', '0'..'9', '_', '\x80'..'\xFF', '.', '/', '\\', '-'}


proc do_transform(self: ref proc(src: string): string, src: string): string =  # {{{1
    result = src.toLower()
    if isNil(self):
        return result
    return self[](src)


proc initConfigParser*(comment_prefixes = @["#", ";"],  # {{{1
                       inline_comment_prefixes = @[";"]): ConfigParser =
    return ConfigParser(
        data: newTable[string, SectionTable](),
        comment_prefixes: comment_prefixes,
        inline_comment_prefixes: inline_comment_prefixes)


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
        if is_match(self.comment_prefixes, i, line, false):
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
                        ): tuple[st: ParseResult, parsed: string] =
    let splitter_opt_val = "=:"
    var f_opt = true
    var f_space = false
    var opt, val: string

    var n_start = c.is_heading_comment(line)
    if n_start < 0:
        return (in_empty, "")

    for n in 0..len(line) - 1:
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
                return (ret, "")
            opt &= $i
        else:
            var f = f_space
            f_space = (i == ' ')
            if c.is_comment(n, line, f):
                break
            val &= $i
    if f_opt:
        return (opt_or_invalid, opt)

    opt = c.optionxform.do_transform(opt)
    if c.cur_section.hasKey(opt):
        return (opt_and_dup, "")
    val = val.strip()
    c.cur_section.add(opt, val)
    return (opt_and_val, val)


# proc read*(c: var ConfigParser, input: IEnumerable[string]): void =  # {{{1


proc read*(c: var ConfigParser, input: iterator(): string): void =  # {{{1
    c.data = newTable[string, SectionTable]()
    c.cur_section = newTable[string, string]()
    c.cur_section_name = ""
    c.data.add("", c.cur_section)

    var line: string
    var cur = ParseResult.in_empty
    for line in input():
        var (st, parsed) = c.parse_option_value(line)
        case st:
        of opt_and_val:
            cur = ParseResult.in_val
        of opt_and_dup:
            cur = ParseResult.in_empty
        of opt_or_invalid:
            if cur == in_val:
                c.cur_val &= parsed
        else:
            discard

    #[

  ## initializes the parser with an input stream. `Filename` is only used
  ## for nice error messages. `lineOffset` can be used to influence the line
  ## number information in the generated error messages.
  lexbase.open(c, input)
  c.filename = filename
  c.tok.kind = tkInvalid
  c.tok.literal = ""
  inc(c.lineNumber, lineOffset)
  rawGetTok(c, c.tok)
    ]#


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
proc close*(c: var CfgParser) {.rtl, extern: "npc$1".} =
  ## closes the parser `c` and its associated input stream.
  lexbase.close(c)

proc getColumn*(c: CfgParser): int {.rtl, extern: "npc$1".} =
  ## get the current column the parser has arrived at.
  result = getColNumber(c, c.bufpos)

proc getLine*(c: CfgParser): int {.rtl, extern: "npc$1".} =
  ## get the current line the parser has arrived at.
  result = c.lineNumber

proc getFilename*(c: CfgParser): string {.rtl, extern: "npc$1".} =
  ## get the filename of the file that the parser processes.
  result = c.filename

proc handleHexChar(c: var CfgParser, xi: var int) =
  case c.buf[c.bufpos]
  of '0'..'9':
    xi = (xi shl 4) or (ord(c.buf[c.bufpos]) - ord('0'))
    inc(c.bufpos)
  of 'a'..'f':
    xi = (xi shl 4) or (ord(c.buf[c.bufpos]) - ord('a') + 10)
    inc(c.bufpos)
  of 'A'..'F':
    xi = (xi shl 4) or (ord(c.buf[c.bufpos]) - ord('A') + 10)
    inc(c.bufpos)
  else:
    discard

proc handleDecChars(c: var CfgParser, xi: var int) =
  while c.buf[c.bufpos] in {'0'..'9'}:
    xi = (xi * 10) + (ord(c.buf[c.bufpos]) - ord('0'))
    inc(c.bufpos)

proc getEscapedChar(c: var CfgParser, tok: var Token) =
  inc(c.bufpos)               # skip '\'
  case c.buf[c.bufpos]
  of 'n', 'N':
    add(tok.literal, "\n")
    inc(c.bufpos)
  of 'r', 'R', 'c', 'C':
    add(tok.literal, '\c')
    inc(c.bufpos)
  of 'l', 'L':
    add(tok.literal, '\L')
    inc(c.bufpos)
  of 'f', 'F':
    add(tok.literal, '\f')
    inc(c.bufpos)
  of 'e', 'E':
    add(tok.literal, '\e')
    inc(c.bufpos)
  of 'a', 'A':
    add(tok.literal, '\a')
    inc(c.bufpos)
  of 'b', 'B':
    add(tok.literal, '\b')
    inc(c.bufpos)
  of 'v', 'V':
    add(tok.literal, '\v')
    inc(c.bufpos)
  of 't', 'T':
    add(tok.literal, '\t')
    inc(c.bufpos)
  of '\'', '"':
    add(tok.literal, c.buf[c.bufpos])
    inc(c.bufpos)
  of '\\':
    add(tok.literal, '\\')
    inc(c.bufpos)
  of 'x', 'X':
    inc(c.bufpos)
    var xi = 0
    handleHexChar(c, xi)
    handleHexChar(c, xi)
    add(tok.literal, chr(xi))
  of '0'..'9':
    var xi = 0
    handleDecChars(c, xi)
    if (xi <= 255): add(tok.literal, chr(xi))
    else: tok.kind = tkInvalid
  else: tok.kind = tkInvalid

proc handleCRLF(c: var CfgParser, pos: int): int =
  case c.buf[pos]
  of '\c': result = lexbase.handleCR(c, pos)
  of '\L': result = lexbase.handleLF(c, pos)
  else: result = pos

proc getString(c: var CfgParser, tok: var Token, rawMode: bool) =
  var pos = c.bufpos + 1          # skip "
  var buf = c.buf                 # put `buf` in a register
  tok.kind = tkSymbol
  if (buf[pos] == '"') and (buf[pos + 1] == '"'):
    # long string literal:
    inc(pos, 2)               # skip ""
                              # skip leading newline:
    pos = handleCRLF(c, pos)
    buf = c.buf
    while true:
      case buf[pos]
      of '"':
        if (buf[pos + 1] == '"') and (buf[pos + 2] == '"'): break
        add(tok.literal, '"')
        inc(pos)
      of '\c', '\L':
        pos = handleCRLF(c, pos)
        buf = c.buf
        add(tok.literal, "\n")
      of lexbase.EndOfFile:
        tok.kind = tkInvalid
        break
      else:
        add(tok.literal, buf[pos])
        inc(pos)
    c.bufpos = pos + 3       # skip the three """
  else:
    # ordinary string literal
    while true:
      var ch = buf[pos]
      if ch == '"':
        inc(pos)              # skip '"'
        break
      if ch in {'\c', '\L', lexbase.EndOfFile}:
        tok.kind = tkInvalid
        break
      if (ch == '\\') and not rawMode:
        c.bufpos = pos
        getEscapedChar(c, tok)
        pos = c.bufpos
      else:
        add(tok.literal, ch)
        inc(pos)
    c.bufpos = pos

proc getSymbol(c: var CfgParser, tok: var Token) =
  var pos = c.bufpos
  var buf = c.buf
  while true:
    add(tok.literal, buf[pos])
    inc(pos)
    if not (buf[pos] in SymChars): break
  c.bufpos = pos
  tok.kind = tkSymbol

proc skip(c: var CfgParser) =
  var pos = c.bufpos
  var buf = c.buf
  while true:
    case buf[pos]
    of ' ', '\t':
      inc(pos)
    of '#', ';':
      while not (buf[pos] in {'\c', '\L', lexbase.EndOfFile}): inc(pos)
    of '\c', '\L':
      pos = handleCRLF(c, pos)
      buf = c.buf
    else:
      break                   # EndOfFile also leaves the loop
  c.bufpos = pos

proc rawGetTok(c: var CfgParser, tok: var Token) =
  tok.kind = tkInvalid
  setLen(tok.literal, 0)
  skip(c)
  case c.buf[c.bufpos]
  of '=':
    tok.kind = tkEquals
    inc(c.bufpos)
    tok.literal = "="
  of '-':
    inc(c.bufpos)
    if c.buf[c.bufpos] == '-':
      inc(c.bufpos)
      tok.kind = tkDashDash
      tok.literal = "--"
    else:
      dec(c.bufpos)
      getSymbol(c, tok)
  of ':':
    tok.kind = tkColon
    inc(c.bufpos)
    tok.literal = ":"
  of 'r', 'R':
    if c.buf[c.bufpos + 1] == '\"':
      inc(c.bufpos)
      getString(c, tok, true)
    else:
      getSymbol(c, tok)
  of '[':
    tok.kind = tkBracketLe
    inc(c.bufpos)
    tok.literal = "]"
  of ']':
    tok.kind = tkBracketRi
    inc(c.bufpos)
    tok.literal = "]"
  of '"':
    getString(c, tok, false)
  of lexbase.EndOfFile:
    tok.kind = tkEof
    tok.literal = "[EOF]"
  else: getSymbol(c, tok)

proc errorStr*(c: CfgParser, msg: string): string {.rtl, extern: "npc$1".} =
  ## returns a properly formatted error message containing current line and
  ## column information.
  result = `%`("$1($2, $3) Error: $4",
               [c.filename, $getLine(c), $getColumn(c), msg])

proc warningStr*(c: CfgParser, msg: string): string {.rtl, extern: "npc$1".} =
  ## returns a properly formatted warning message containing current line and
  ## column information.
  result = `%`("$1($2, $3) Warning: $4",
               [c.filename, $getLine(c), $getColumn(c), msg])

proc ignoreMsg*(c: CfgParser, e: CfgEvent): string {.rtl, extern: "npc$1".} =
  ## returns a properly formatted warning message containing that
  ## an entry is ignored.
  case e.kind
  of cfgSectionStart: result = c.warningStr("section ignored: " & e.section)
  of cfgKeyValuePair: result = c.warningStr("key ignored: " & e.key)
  of cfgOption:
    result = c.warningStr("command ignored: " & e.key & ": " & e.value)
  of cfgError: result = e.msg
  of cfgEof: result = ""

proc getKeyValPair(c: var CfgParser, kind: CfgEventKind): CfgEvent =
  if c.tok.kind == tkSymbol:
    result.kind = kind
    result.key = c.tok.literal
    result.value = ""
    rawGetTok(c, c.tok)
    if c.tok.kind in {tkEquals, tkColon}:
      rawGetTok(c, c.tok)
      if c.tok.kind == tkSymbol:
        result.value = c.tok.literal
      else:
        reset result
        result.kind = cfgError
        result.msg = errorStr(c, "symbol expected, but found: " & c.tok.literal)
      rawGetTok(c, c.tok)
  else:
    result.kind = cfgError
    result.msg = errorStr(c, "symbol expected, but found: " & c.tok.literal)
    rawGetTok(c, c.tok)

proc next*(c: var CfgParser): CfgEvent {.rtl, extern: "npc$1".} =
  ## retrieves the first/next event. This controls the parser.
  case c.tok.kind
  of tkEof:
    result.kind = cfgEof
  of tkDashDash:
    rawGetTok(c, c.tok)
    result = getKeyValPair(c, cfgOption)
  of tkSymbol:
    result = getKeyValPair(c, cfgKeyValuePair)
  of tkBracketLe:
    rawGetTok(c, c.tok)
    if c.tok.kind == tkSymbol:
      result.kind = cfgSectionStart
      result.section = c.tok.literal
    else:
      result.kind = cfgError
      result.msg = errorStr(c, "symbol expected, but found: " & c.tok.literal)
    rawGetTok(c, c.tok)
    if c.tok.kind == tkBracketRi:
      rawGetTok(c, c.tok)
    else:
      reset(result)
      result.kind = cfgError
      result.msg = errorStr(c, "']' expected, but found: " & c.tok.literal)
  of tkInvalid, tkEquals, tkColon, tkBracketRi:
    result.kind = cfgError
    result.msg = errorStr(c, "invalid token: " & c.tok.literal)
    rawGetTok(c, c.tok)
]#

# ---------------- Configuration file related operations ----------------
type
  Config* = OrderedTableRef[string, OrderedTableRef[string, string]]

proc newConfig*(): Config =
  ## Create a new configuration table.
  ## Useful when wanting to create a configuration file.
  result = newOrderedTable[string, OrderedTableRef[string, string]]()

proc loadConfig*(stream: Stream, filename: string = "[stream]"): Config =
  ## Load the specified configuration from stream into a new Config instance.
  ## `filename` parameter is only used for nicer error messages.
  var dict = newOrderedTable[string, OrderedTableRef[string, string]]()
  var curSection = "" ## Current section,
                      ## the default value of the current section is "",
                      ## which means that the current section is a common
  #[
  var p: CfgParser
  open(p, stream, filename)
  while true:
    var e = next(p)
    case e.kind
    of cfgEof:
      break
    of cfgSectionStart: # Only look for the first time the Section
      curSection = e.section
    of cfgKeyValuePair:
      var t = newOrderedTable[string, string]()
      if dict.hasKey(curSection):
        t = dict[curSection]
      t[e.key] = e.value
      dict[curSection] = t
    of cfgOption:
      var c = newOrderedTable[string, string]()
      if dict.hasKey(curSection):
        c = dict[curSection]
      c["--" & e.key] = e.value
      dict[curSection] = c
    of cfgError:
      break
  close(p)
  result = dict
  ]#

proc loadConfig*(filename: string): Config =
  ## Load the specified configuration file into a new Config instance.
  let file = open(filename, fmRead)
  let fileStream = newFileStream(file)
  defer: fileStream.close()
  result = fileStream.loadConfig(filename)

proc replace(s: string): string =
  var d = ""
  var i = 0
  while i < s.len():
    if s[i] == '\\':
      d.add(r"\\")
    elif s[i] == '\c' and s[i+1] == '\L':
      d.add(r"\n")
      inc(i)
    elif s[i] == '\c':
      d.add(r"\n")
    elif s[i] == '\L':
      d.add(r"\n")
    else:
      d.add(s[i])
    inc(i)
  result = d

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

proc `$`*(dict: Config): string =
  ## Writes the contents of the table to string.
  ## Note: Comment statement will be ignored.
  let stream = newStringStream()
  defer: stream.close()
  dict.writeConfig(stream)
  result = stream.data

proc writeConfig*(dict: Config, filename: string) =
  ## Writes the contents of the table to the specified configuration file.
  ## Note: Comment statement will be ignored.
  let file = open(filename, fmWrite)
  defer: file.close()
  let fileStream = newFileStream(file)
  dict.writeConfig(fileStream)

proc getSectionValue*(dict: Config, section, key: string): string =
  ## Gets the Key value of the specified Section.
  if dict.haskey(section):
    if dict[section].hasKey(key):
      result = dict[section][key]
    else:
      result = ""
  else:
    result = ""

proc setSectionKey*(dict: var Config, section, key, value: string) =
  ## Sets the Key value of the specified Section.
  var t = newOrderedTable[string, string]()
  if dict.hasKey(section):
    t = dict[section]
  t[key] = value
  dict[section] = t

proc delSection*(dict: var Config, section: string) =
  ## Deletes the specified section and all of its sub keys.
  dict.del(section)

proc delSectionKey*(dict: var Config, section, key: string) =
  ## Delete the key of the specified section.
  if dict.haskey(section):
    if dict[section].hasKey(key):
      if dict[section].len() == 1:
        dict.del(section)
      else:
        dict[section].del(key)


proc get*(self: ConfigParser, section, option: string, raw = false,  # {{{1
          vars: TableRef[string, string] = nil, fallback: string = ""): string =
    var ret = ""
    var opt = self.optionxform.do_transform(option)
    if not isNil(vars):  # vars is 1st priority.
        if vars.hasKey(opt):
            return vars[opt]

    # 2nd search in section.
    if self.data.hasKey(section):
        var tbl = self.data[section]
        if tbl.hasKey(opt):
            return tbl[opt]

    # 3rd search in default section.
    var tbl = self.data[""]
    if tbl.hasKey(opt):
        return tbl[opt]

    if len(fallback) < 1:  # finally go into fallback.
        raise newException(NoOptionError, "does not have option: " & opt)
    return fallback


proc get*(self: SectionTable, option: string): string =  # {{{1
    var ret = ""
    var opt = do_transform(nil, option)
    if not self.hasKey(opt):
        raise newException(NoOptionError, "does not have option: " & opt)
    return self[opt]


proc getint*(self: ConfigParser, section, option: string, raw = false,  # {{{1
             vars: TableRef[string, string] = nil,
             fallback: tuple[en: bool, n: int] = (false, 0)): int =
    var src = if fallback.en: self.get(section, option, raw, vars, $fallback.n)
              else:           self.get(section, option, raw, vars)
    var ret = parseInt(src)
    return ret


proc getint*(self: SectionTable, option: string): int =  # {{{1
    var ret = parseInt(self[option])
    return ret


proc getfloat*(self: ConfigParser, section, option: string, raw = false,  # {{{1
               vars: TableRef[string, string] = nil,
               fallback: tuple[en: bool, n: float] = (false, 0.0)): float =
    try:
        var src = self.get(section, option, raw, vars)
        var ret = parseFloat(src)
        return ret
    except NoOptionError as e:
        if fallback.en:
            return fallback.n
        raise e


proc getfloat*(self: SectionTable, option: string): float =  # {{{1
    var ret = parseFloat(self[option])
    return ret


proc getboolean_chk(src: string): bool =  # {{{1
    for pat in @["yes", "on", "true", "1"]:
        if src == pat:
            return true
    for pat in @["no", "off", "false", "0"]:
        if src == pat:
            return false
    raise newException(ParsingError, ":" & src)


proc getboolean*(self: ConfigParser, section, option: string, raw = false,  # {{{1
                 vars: TableRef[string, string] = nil,
                 fallback: tuple[en: bool, n: bool] = (false, false)): bool =
    try:
        var src = self.get(section, option, raw, vars)
        return getboolean_chk(src)
    except NoOptionError as e:
        if fallback.en:
            return fallback.n
        raise e


proc getboolean*(self: SectionTable, option: string): bool =  # {{{1
    var src = self[option]
    return getboolean_chk(src)


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


proc `[]`*(self: var ConfigParser, section: string): SectionTable =  # {{{1
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
    return self.data[section].hasKey(option)


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


# vi: ft=nim:et:ts=4:fdm=marker:nowrap
