# `py_configparser`
yet another configuration file parser like python


## status

### class

class                 |   | memo
----------------------|---|-----
RawConfigParser       |   |
ConfigParser          |   |
BasicInterpolation    |   |
ExtendedInterpolation |   |


### method

method / property         |     | memo
--------------------------|-----|------
`BOOLEAN_STATES`          | no  |
`optionxform(option)`     | no  |
`SECTCRE`                 | no  |
`defaults()`              |     |
`sections()`              |     |
`add_section()`           |     |
`has_section()`           |     |
`options()`               |     |
`has_option()`            |     |
`read()`                  |     |
`read_file()`             |     |
`read_string()`           |     |
`read_dict()`             |     |
`get()`                   |     |
`getint()`                |     |
`getfloat()`              |     |
`getboolean()`            |     |
`items()`                 |     |
`items()`                 |     |
`set()`                   |     |
`write()`                 |     |
`remove_option()`         |     |
`remove_section()`        |     |
`optionxform()`           |     |
`readfp()`                |     |
`MAX_INTERPOLATION_DEPTH` |     |


RawConfigParser Objects

    add_section(section)
    set(section, option, value)


### Exceptions

Exceptions              | converted | memo
--------------------------------|---|-------
Error                           |   | 
NoSectionError                  |   | 
DuplicateSectionError           |   | 
DuplicateOptionError            |   | 
NoOptionError                   |   | 
InterpolationError              |   | 
InterpolationDepthError         |   | 
InterpolationMissingOptionError |   | 
InterpolationSyntaxError        |   | 
MissingSectionHeaderError       |   | 
ParsingError                    |   | 


