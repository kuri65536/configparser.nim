`configparser`
===============================================================================
yet another configuration file parser to able python behaviors.

- can parse multiline values. (thats I need it.)
- can use interpolation.
<!-- - can change delimiters. -->

but this module not use regex for parsing,
compared from original python implementation.

This repository goal is to make up my project compatiblity in python and nim,
not enable to implement the all features.



How to use
-----------------------------------------
use from your nim project, install from nimble and import this.

use from nimble::

```shell
$ nimble install https://github.com/kuri65536/configparser.nim
```

from git::

```shell
$ git clone install https://github.com/kuri65536/configparser.nim configparser
$ cat > test.nim <<EOF
import configparser/src/configparser
var cf = initConfigParser()
cf.read_string("[test]\na = b")
echo cf.get("test", "b")
EOF
$ nim c -r test.nim
```


### Requirements
- nim (>= 0.19.4)


### In Debian buster
```shell
$ sudo apt intall nim
```



TODO
-----------------------------------------
- complete `default section`
- the delimiter option
- the strict option
- ??? complex expressions in interpolations.

### no plan to implement
- T.B.D...
- the option: `allow_no_value`



Implement status
-----------------------------------------

### class

class             | impl. | memo
----------------------|---|-----
RawConfigParser       | x | no-plan to implement.
ConfigParser          | o |
BasicInterpolation    | o |
ExtendedInterpolation | o |


### method

method / property       | impl. | memo
--------------------------|-----|------
`BOOLEAN_STATES`          | o   | ...
`MAX_INTERPOLATION_DEPTH` | o   | ...
`optionxform(option)`     | o   | affects on every read, get, or set operation.
`SECTCRE`                 |     | no-plan to implement. (hard coded in this module)
`defaults()`              | o   | ...
`sections()`              | o   | ...
`add_section()`           | o   | ...
`has_section()`           | o   | ...
`options()`               | o   | ...
`has_option()`            | o   | ...
`read()`                  | o   | ...
`read_file()`, `readfp()` | o   | ...
`read_string()`           | o   | ...
`read_dict()`             | o   | ...
`get()`                   | o   | ...
`getint()`                | o   | ...
`getfloat()`              | o   | ...
`getboolean()`            | o   | ...
`items()`                 | o   | ...
`items()`                 | o   | ...
`set()`                   | o   | ...
`write()`                 | o   | ...
`remove_option()`         | o   | ...
`remove_section()`        | o   | ...



### Exceptions

Exceptions                  | impl. | memo
--------------------------------|---|-------
Error                           | o | base of exceptions in this module.
NoSectionError                  | o | ...
DuplicateSectionError           | o | ...
DuplicateOptionError            | o | ...
NoOptionError                   | o | ...
InterpolationError              |   | ...
InterpolationDepthError         | o | ...
InterpolationMissingOptionError | o | ...
InterpolationSyntaxError        |   | ...
MissingSectionHeaderError       |   | ...
ParsingError                    | o | ...



Development Environment
-----------------------------------------

| term | description   |
|:----:|:--------------|
| OS   | Debian on Android 10 |
| lang | nim 0.19.4 (OS default) |



Reference
-----------------------------------------
- https://docs.python.org/ja/3/library/configparser.html



License
-----------------------------------------
see the top of source code, it is MPL2.0.



Samples
-----------------------------------------
see tests folder.



Release
-----------------------------------------
| version | description |
|:-------:|:------------|
| 0.2.4   | fix to build against nim 2.0.4 |
| 0.2.3   | fix to reduce warnings in nim 1.4.6 |
| 0.2.2   | bugfix for `read_file()` |
| 0.2.1   | implement `write()` function |
| 0.2.0   | rename to configparser, remove heading `py_` |
| 0.1.0   | 1st version |



Donations
---------------------
If you are feel to nice for this software, please donation to my

- Bitcoin **| 19AyoXxhm8nzgcxgbiXNPkiqNASfc999gJ |**
- Ether **| 0x3a822c36cd5184f9ff162c7a55709f3d6d861608 |**
- or librapay, I'm glad from smaller (about $1)

<!--
vi: ft=markdown:et:fdm=marker
-->
