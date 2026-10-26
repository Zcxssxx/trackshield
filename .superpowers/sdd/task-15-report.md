# Task 15 report: user documentation, license, and provenance

Date: 2026-10-26 (Asia/Shanghai)

## Documentation and example changes

- Replaced the scaffold README with install/strict-check commands, native CLI
  audit examples in text and JSON, defaults and limits, redaction preview and
  write workflows, metadata category labels, exit codes, format constraints,
  error behavior, and privacy limits.
- Added public API notes to `README.mbt.md` and a development guide covering
  layout, generated interfaces, strict local checks, test strategy, dependency
  updates, and privacy-aware review.
- Added `examples/README.md`, a changelog, and a synthetic fixture provenance
  explanation. Changed the three authored example end points so only their
  nearby starts form a component at the default radius. Actual text and JSON
  audit output each report exactly one three-file start component.
- Added exact direct and transitive dependency versions, upstream origins,
  license metadata, source-copy status, and attribution/redistribution notes
  in `THIRD_PARTY_NOTICES.md`.

The documentation review initially identified that the write example did not
repeat the metadata-removal options used in the preceding preview, and that the
`moonbitlang/x` local package had no bundled `LICENSE` file. Both issues were
corrected; review of the fixes found no remaining actionable issues. The write
command was rerun with the metadata options and reported `files=3 ready=3
failed=0 written=3`; each file showed one selected metadata field removed.
The temporary `cleaned/` output was deleted after checking the results.

## License and dependency provenance

The project metadata already declared `Apache-2.0`. OSI lists that identifier
as an approved license: <https://opensource.org/license/apache-2.0/>. The root
`LICENSE` is the Apache License, Version 2.0 text copied from the fetched
`moongpx` package's license file. Its SHA-256 is
`CFC7749B96F63BD31C3C42B5C471BF756814053E847C10F3EB003417BC523D30`, matching
the fetched `moongpx`, `xml`, and `async` LICENSE files. The `moonbitlang/x`
manifest declares Apache-2.0 but its fetched directory has no `LICENSE` file.
No dependency source or upstream fixture is copied into the project, and no
fetched dependency directory contains a separate `NOTICE` file.

Pinned dependency graph:

| Module | Version | Role | License |
| --- | --- | --- | --- |
| `2973181701/moongpx` | `0.1.0` | Direct GPX parser/model | Apache-2.0 |
| `Milky2018/xml` | `0.4.1` | Direct; also required by moongpx | Apache-2.0 |
| `moonbitlang/async` | `0.22.5` | Direct native CLI filesystem/I/O | Apache-2.0 |
| `moonbitlang/x` | `0.5.1` | Transitive through xml | Apache-2.0 |

The examples and test collections are original hand-authored synthetic data,
not recorded activity or personal location data; the project license applies.

## Verification

| Command | Exit | Result |
| --- | --- | --- |
| `moon version --all` | 0 | `moon 0.1.20261023`; `moonc v0.10.17+d971670cd`; `moonrun 0.1.20261023` |
| `moon fmt --check` | 0 | Passed after applying the formatter's documented MoonBit snippet formatting to `README.mbt.md` |
| `moon check --deny-warn` | 0 | Passed with no MoonBit warnings |
| `moon test --deny-warn` | 0 | 142/142 passed |
| `moon build --target native --deny-warn` | 0 | Native CLI built; upstream async C emitted Windows SDK macro warning C4005 for `EINVAL` |
| `moon info` | 0 | Passed; no generated interface diff |
| `git diff --check` | 0 | Passed; Git reported only LF-to-CRLF notices |
| All shell commands in `README.md`, `README.mbt.md`, `examples/README.md`, and `docs/development.md` | 0 | Build/check/test/help, text and JSON audit, option override, redaction preview, and write example passed; output cleaned after verification |

The first bulk command pass exposed a Markdown formatting difference in
`README.mbt.md` and a harness mistake that invoked `moon diff --check` instead
of `git diff --check`. Ran `moon fmt`, reran the MoonBit formatter check, and
ran the Git whitespace check separately; both final checks passed. The final
redaction write example was rerun after review with the corrected options.

## Scope boundary

This work remains local-only. No remote is configured, no authenticated
GitHub identity or token was queried, and no repository, push, or hosted CI
operation was performed. The installed compiler version is recorded, but its
status as the newest official stable version remains to be reconciled in Task
17 before the CI workflow pins it.
