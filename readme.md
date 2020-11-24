# `py_configparser`
yet another configuration file parser like python


## status

### class

class             | impl. | memo
----------------------|---|-----
RawConfigParser       |   |
ConfigParser          | o |
BasicInterpolation    |   |
ExtendedInterpolation |   |


### method

method / property       | impl. | memo
--------------------------|-----|------
`BOOLEAN_STATES`          | o   | ...
`optionxform(option)`     | o   | affects on every read, get, or set operation.
`SECTCRE`                 | no  | ...
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
`write()`                 |     |
`remove_option()`         | o   | ...
`remove_section()`        | o   | ...
`MAX_INTERPOLATION_DEPTH` |     |


RawConfigParser Objects

    add_section(section)
    set(section, option, value)


### Exceptions

Exceptions                  | impl. | memo
--------------------------------|---|-------
Error                           | o | base of exceptions in this module.
NoSectionError                  | o | ...
DuplicateSectionError           | o | ...
DuplicateOptionError            | o | ...
NoOptionError                   | o | ...
InterpolationError              |   | ...
InterpolationDepthError         |   | ...
InterpolationMissingOptionError |   | ...
InterpolationSyntaxError        |   | ...
MissingSectionHeaderError       |   | ...
ParsingError                    | o | ...


