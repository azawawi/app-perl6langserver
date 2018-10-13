# App::Perl6LangServer

 [![Build Status](https://travis-ci.org/azawawi/app-perl6langserver.svg?branch=master)](https://travis-ci.org/azawawi/app-perl6langserver) [![Build status](https://ci.appveyor.com/api/projects/status/github/azawawi/app-perl6langserver?svg=true)](https://ci.appveyor.com/project/azawawi/app-perl6langserver/branch/master)

This is usually used with a language client (e.g.
[ide-perl6](https://github.com/azawawi/ide-perl6)). This language server
only supports at the moment `stdin` / `stdout` mode.

This 
**Note: This is currently experimental and API may change. Please DO NOT use in
a production environment.**

## Example

```bash
# To run the language server in stdin / stdout mode
$ perl6-langserver
```

## Installation

- Install this module using [zef](https://github.com/ugexe/zef):

```
$ zef install App::Perl6LangServer
```

## Testing

- To run tests:
```
$ prove -ve "perl6 -Ilib"
```

- To run all tests including author tests (Please make sure
[Test::Meta](https://github.com/jonathanstowe/Test-META) is installed):
```
$ zef install Test::META
$ AUTHOR_TESTING=1 prove -e "perl6 -Ilib"
```

## Author

Ahmad M. Zawawi, [azawawi](https://github.com/azawawi/) on #perl6.

## License

MIT License
