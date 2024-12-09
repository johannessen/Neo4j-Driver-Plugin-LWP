Neo4j::Driver::Plugin::LWP
==========================

This software is a [Neo4j::Driver::Plugin][] that provides an
HTTP network adapter, using [libwww-perl][] to connect to the
Neo4j server via HTTP or HTTPS.

[Neo4j::Driver::Plugin]: https://metacpan.org/pod/Neo4j::Driver::Plugin
[libwww-perl]: https://metacpan.org/dist/libwww-perl


Installation
------------

Released versions of [Neo4j::Driver::Plugin::LWP][]
may be installed via CPAN:

    cpanm Neo4j::Driver::Plugin::LWP

[![CPAN distribution](https://badge.fury.io/pl/Neo4j-Driver-Plugin-LWP.svg)](https://badge.fury.io/pl/Neo4j-Driver-Plugin-LWP)

To install a development version from this repository,
run the following steps:

```sh
git clone https://github.com/johannessen/Neo4j-Driver-Plugin-LWP
cd Neo4j-Driver-Plugin-LWP
cpanm Dist::Zilla::PluginBundle::Author::AJNN
dzil install
```

[![Build and Test](https://github.com/johannessen/Neo4j-Driver-Plugin-LWP/actions/workflows/test.yaml/badge.svg)](https://github.com/johannessen/Neo4j-Driver-Plugin-LWP/actions/workflows/test.yaml)

This is a “Pure Perl” module, so you generally do not need
Dist::Zilla to contribute patches. You can simply clone the
repository and run the test suite using `prove` instead.

[Neo4j::Driver::Plugin::LWP]: https://metacpan.org/dist/Neo4j-Driver-Plugin-LWP
