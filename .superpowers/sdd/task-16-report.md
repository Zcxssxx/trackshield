# Task 16 report: local MoonBit CI workflow

Date: 2026-10-26 (Asia/Shanghai)

## Workflow

Added `.github/workflows/test.yml` as a local repository file only. On push,
pull request, or manual dispatch it has:

- A native job that installs MoonBit through the official `latest` channel,
  prints `moon version --all`, resolves/logs the `moon.mod`-pinned dependency
  graph, runs formatter and strict native check/test/build, executes text/JSON
  audit and redaction-preview examples, runs `moon info`, and fails if the
  checkout has any generated or other working-tree diff.
- A matrix for `wasm`, `wasm-gc`, and `js` that checks, tests, and builds only
  the reusable library packages: `api`, `audit`, `geo`, `gpx`, `internal/xmlguard`,
  `model`, `redact`, and `report`.

The CLI and filesystem integration packages remain native-only. A full
workspace `wasm-gc` check fails because the pinned `moonbitlang/async` version
does not expose `run_async_main` and the required `async/fs` operations on that
target. The library package selection avoids that boundary without claiming
that the executable itself supports those targets.

The current module has no `moon.lock` file. `moon.mod` pins exact direct
dependency versions; `moon tree --json` reports the resolved graph, including
transitive `moonbitlang/x@0.5.1`. CI resolves packages through the normal Moon
build/check flow and logs the graph; it does not claim an absent lock file.

## Toolchain version status

Local `moon version --all` reports `moon 0.1.20261023`, `moonc
v0.10.17+d971670cd`, and `moonrun 0.1.20261023`. CI uses the official
`https://cli.moonbitlang.com/install/unix.sh` `latest` channel and prints the
resolved versions, rather than silently selecting a development channel. The
official installation page describes installing the latest toolchain but does
not name its version; the official updates index currently shows v0.10.14 dated
September 21, while the installed compiler is v0.10.17 dated October 23. The
official `latest` checksum endpoint could not be retrieved with the local
network client (it returned an authentication error), and no hosted CI run is
available yet. Therefore the CI/local exact latest-version match remains
unverified for Task 17; this report does not claim that the installed build is
proven to be the absolute newest release.

## Local verification

| Command | Exit | Result |
| --- | --- | --- |
| `moon version --all` | 0 | `moon 0.1.20261023`, `moonc v0.10.17+d971670cd`, `moonrun 0.1.20261023` |
| `moon tree --json` | 0 | Direct versions: moongpx 0.1.0, xml 0.4.1, async 0.22.5; transitive x 0.5.1 |
| `moon fmt --check` | 0 | Passed |
| `moon check --target native --deny-warn` | 0 | Passed |
| `moon test --target native --deny-warn` | 0 | 142/142 passed |
| `moon build --target native --deny-warn` | 0 | Native CLI artifact built |
| `moon check --target wasm-gc --deny-warn` | 1 | Expected unsupported full-workspace boundary: 169 missing async/async-fs symbol errors in CLI and filesystem test code |
| README audit text, JSON, override, redaction preview/write examples | 0 | Passed earlier in Task 15; CI smoke commands also match these examples |
| `moon info` | 0 | Passed; tracked and untracked generated `.mbti` files unchanged |
| PyYAML 6.0.2 `safe_load(.github/workflows/test.yml)` | 0 | Parsed; verified triggers and `[wasm, wasm-gc, js]` matrix |
| `git diff --check` | 0 | Passed; only line-ending notices from Git on Windows |

The following library-package commands were run separately for each target
`wasm`, `wasm-gc`, and `js`; each command exited 0 and each test run passed
113/113:

```sh
moon check --target wasm --deny-warn --no-mbti api audit geo gpx internal/xmlguard model redact report
moon test --target wasm --deny-warn api audit geo gpx internal/xmlguard model redact report
moon build --target wasm --deny-warn api audit geo gpx internal/xmlguard model redact report
moon check --target wasm-gc --deny-warn --no-mbti api audit geo gpx internal/xmlguard model redact report
moon test --target wasm-gc --deny-warn api audit geo gpx internal/xmlguard model redact report
moon build --target wasm-gc --deny-warn api audit geo gpx internal/xmlguard model redact report
moon check --target js --deny-warn --no-mbti api audit geo gpx internal/xmlguard model redact report
moon test --target js --deny-warn api audit geo gpx internal/xmlguard model redact report
moon build --target js --deny-warn api audit geo gpx internal/xmlguard model redact report
```

Native Windows C compilation emitted dependency warning C4005 for `EINVAL` in
`moonbitlang/async`; strict MoonBit checks/tests passed and the dependency
warning was not suppressed. The workflow does not claim hosted CI, YAML schema
validation by GitHub, or cross-operating-system native test execution.

## Review and local-only boundary

Independent workflow review confirmed command flags and target scope against
local `moon` help and execution. The review asked for recorded per-target
results and for the plan's stable-version acceptance to match the floating
`latest` installer. This report records the target results and leaves exact
version reconciliation pending Task 17; the plan acceptance now says the same.

No GitHub repository was created, accessed through an authenticated account,
or modified. No remote is configured and no hosted CI run was requested.
