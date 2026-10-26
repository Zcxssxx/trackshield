# Development guide

## Prerequisites and setup

Use the latest stable MoonBit toolchain installed through the
[official installation guide](https://www.moonbitlang.com/download/). Record
`moon version --all` when changing the toolchain or CI. `moon.mod` pins the
Mooncakes dependency versions; Moon creates `.mooncakes/` and `_build/` as local
generated state. They are ignored by Git and are not source-of-truth copies.

From the repository root, the strict native checks are:

```sh
moon version --all
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon build --target native --deny-warn
moon info
git diff --check
```

`moon info` may refresh generated package interfaces such as
`pkg.generated.mbti`. Review generated interface changes with the source change;
do not add unrelated generated diffs. `moon fmt --check` and `moon info` do not
take `--deny-warn` in the current CLI. The local CI workflow runs the complete
suite on native and builds/tests the library packages on `wasm`, `wasm-gc`, and
`js`. It omits `cmd/main` and filesystem integration packages from portable
jobs: a workspace-wide `wasm-gc` check currently fails because the pinned
`moonbitlang/async` packages do not expose the CLI's async entrypoint and
filesystem operations on that target. The library-only target matrix has
passed locally. A successful local command is not a claim about hosted CI.

To run the native CLI and the synthetic demonstrations, use the commands in
the root README. The native CLI is the first-release executable target. The
library is separated from the filesystem/argument boundary to keep core audit,
reporting, parsing, and in-memory redaction operations reusable.

## Source layout

- `api/`: public facade and end-to-end library tests.
- `model/`: validated public data types, limits, and diagnostics.
- `gpx/`, `internal/xmlguard/`: bounded GPX and XML preflight/parsing.
- `geo/`, `audit/`, `report/`: distance calculations, collection analysis,
  and deterministic text/JSON output.
- `redact/`: explicit-zone preview and loss-aware in-memory transformation.
- `cmd/main/`: CLI parsing, local file discovery, bounded reads, and staged
  output publication.
- `examples/`: synthetic user-facing demonstration input.
- `testdata/`: authored synthetic regression/integration fixtures.
- `docs/`: privacy and format contracts, design specification, and plan.

## Tests and changes

Keep input parsing, audit, report rendering, and in-memory redaction behavior
covered by MoonBit tests near their packages. The CLI integration tests cover
file traversal, output staging, diagnostic streams, and platform-specific path
behavior. Add source code for a real user or correctness need, together with a
regression test; do not use generated volume to inflate the project.

For dependency changes, update the exact version in `moon.mod`, inspect the
resolved tree with `moon tree`, check the upstream license and module metadata,
and revise `THIRD_PARTY_NOTICES.md`. Do not copy upstream implementation or
test fixtures without documenting their exact source and license. Current
dependency and fixture records are in that notice file.

## Privacy-aware review

Before accepting a report or redaction change, check that diagnostics do not
echo source values, default renderings do not expose coordinates, and
caller-provided data is not mutated. Redaction must remain independent of audit
findings, require an explicit center and radius, preserve removed track gaps as
separate segments, and avoid writing into existing paths. Treat file names,
reports, temporary output, and retained route content as sensitive. For the
operational limits and filesystem guarantees, read [formats and limits](formats-and-limits.md).
