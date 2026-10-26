# Third-party notices and provenance

TrackShield is licensed under Apache-2.0. Direct dependency versions are pinned
in `moon.mod`; the transitive resolution below was confirmed from the local
Moon module manifests and resolved Moon tree. Mooncakes package pages are
linked where available; upstream repository links provide source provenance.

| Module | Version | Relationship and use | Upstream source | License |
| --- | --- | --- | --- | --- |
| `2973181701/moongpx` | `0.1.0` | Direct; GPX model, parsing and semantic validation | [repository](https://github.com/2973181701/moongpx) | Apache-2.0 |
| `Milky2018/xml` | `0.4.1` | Direct and used by `moongpx`; XML events and source spans | [repository](https://github.com/moonbit-community/xml-mbt), [Mooncakes version](https://mooncakes.io/docs/Milky2018/xml%400.4.1) | Apache-2.0 |
| `moonbitlang/async` | `0.22.5` | Direct; native CLI filesystem and asynchronous I/O boundary | [repository](https://github.com/moonbitlang/async), [Mooncakes version](https://mooncakes.io/docs/moonbitlang/async%400.22.5) | Apache-2.0 |
| `moonbitlang/x` | `0.5.1` | Transitive through `Milky2018/xml`; XML parser support | [repository](https://github.com/moonbitlang/x), [Mooncakes version](https://mooncakes.io/docs/moonbitlang/x%400.5.1) | Apache-2.0 |

The exact fetched module manifests identify all four package licenses as
Apache-2.0. The bundled `LICENSE` files for `moongpx`, `xml`, and `async` have
matching SHA-256 digests. The fetched `moonbitlang/x@0.5.1` directory has no
`LICENSE` file; its module manifest declares Apache-2.0. The fetched dependency
directories contained no separate `NOTICE` file. No
dependency source or upstream fixture is copied into the TrackShield source
tree; `.mooncakes/` is local generated package state and is Git-ignored. The
root `LICENSE` contains the Apache License, Version 2.0 text. The
[Open Source Initiative lists Apache-2.0 as an approved license](https://opensource.org/license/apache-2.0/).

When redistributing dependency artifacts or binaries, retain the applicable
Apache-2.0 license terms and any upstream notices supplied with the artifact.
This table is provenance information and does not claim ownership of upstream
work. Check the exact package version and its included legal files again before
changing versions or distributing a bundle.

## GPX examples and test fixtures

Every file under `examples/repeated-endpoints/` and `testdata/` is original,
hand-authored synthetic data created for TrackShield. There are no recorded
activities, personal data, upstream fixtures, or copied route geometry. The
fixture license follows the project license in the root `LICENSE`.

## License references

- [Apache License, Version 2.0 (Apache Software Foundation)](https://www.apache.org/licenses/LICENSE-2.0)
- [OSI approval entry for Apache-2.0](https://opensource.org/license/apache-2.0/)
