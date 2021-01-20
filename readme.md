`configparser`
===============================================================================
yet another configuration file parser like python behaviors.


## install



## implement status

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
`write()`                 |     |
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


