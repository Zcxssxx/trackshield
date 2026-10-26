# Task 17 report: final local verification and submission readiness

Date: 2026-10-26 (Asia/Shanghai)

## Toolchain and contest rules

`moon version --all` reports:

```text
moon 0.1.20261023 (3778465 2026-10-23)
moonc v0.10.17+d971670cd (2026-10-23)
moonrun 0.1.20261023
```

The installed command's `moon upgrade --help` states that `--dev` installs the latest development version. On 2026-10-26, `moon upgrade` without `--dev` completed successfully through the default stable channel. It installed to `C:\Users\gunter\.moon`; a subsequent `moon version --all` still reported `moon 0.1.20261023`, `moonc v0.10.17+d971670cd`, and `moonrun 0.1.20261023`. The default stable updater therefore resolved to v0.10.17 on this host. The CI workflow now invokes the official installer with no channel override and prints the resolved version. The official [MoonBit updates index](https://www.moonbitlang.com/updates) still lists [v0.10.14, dated 2026-09-21](https://www.moonbitlang.com/updates/2026/09/21/index) as its latest monthly announcement; this lag is recorded rather than used to downgrade the working default stable channel. The Hackathon-specific toolchain clause remains `待确认` because its formal charter was inaccessible, and hosted CI remains unverified.

The upgrader warned that the command is highly experimental and emitted a non-fatal PowerShell `Set-ExecutionPolicy` module-loading diagnostic. It nevertheless exited 0, printed “Moonbit installed successfully,” and completed the post-upgrade version check. The repeated version output and successful project matrix are the verification evidence; the installer warning was not hidden.

The current [October Hackathon landing page](https://moonbitlang.github.io/Hackathon2026/) states registration and acceptance close on 2026-10-31, but its retrieved page content does not show an update date or cutoff time/time zone. The [formal charter](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd) and [supplement](https://bxup9uklfcb.feishu.cn/wiki/KNrVwEVFziPHiGkQtwhc6w3gndd) remain inaccessible through current retrieval. Exact form fields/file type, review details, precise license terms, Mooncakes, CI, and stable-toolchain clauses remain `待确认`. A landing-page-based checklist and unsubmitted project description draft are in `docs/submission-readiness.md`.

## Fresh local verification

All commands below were run from the project root after commit `7e8d7dc` and before this report commit. Native commands used `--deny-warn`; `moon info` intentionally did not use a warning-denial flag.

| Command | Exit | Result |
| --- | ---: | --- |
| `moon version --all` after default stable-channel `moon upgrade` | 0 | `moon 0.1.20261023`; `moonc v0.10.17+d971670cd`; `moonrun 0.1.20261023` |
| `moon upgrade` (default stable channel; no `--dev`) | 0 | Installed successfully; same resolved versions before and after |
| `moon fmt --check` | 0 | No formatting work required |
| `moon check --target native --deny-warn` | 0 | 33 tasks up to date |
| `moon test --target native --deny-warn` | 0 | 142/142 passed |
| `moon build --target native --deny-warn` | 0 | Native CLI artifact built |
| `moon check --target wasm --deny-warn --no-mbti api audit geo gpx internal/xmlguard model redact report` | 0 | Passed |
| Same library check for `wasm-gc` | 0 | Passed |
| Same library check for `js` | 0 | Passed |
| `moon test --target wasm --deny-warn api audit geo gpx internal/xmlguard model redact report` | 0 | 113/113 passed |
| Same library tests for `wasm-gc` | 0 | 113/113 passed |
| Same library tests for `js` | 0 | 113/113 passed |
| `moon build --target wasm --deny-warn api audit geo gpx internal/xmlguard model redact report` | 0 | Passed |
| Same library build for `wasm-gc` | 0 | Passed |
| Same library build for `js` | 0 | Passed |
| `moon run cmd/main -- --help` | 0 | CLI usage/help printed |
| `moon info` | 0 | Passed; no interface snapshot change |
| All README audit, JSON, override, redact-preview, metadata-preview and explicit-write examples | 0 | All passed; write produced three nonempty validated copies in a temporary output directory, then it was removed |
| `git diff --check` | 0 | Passed |
| `git diff --exit-code` after `moon info` | 0 | Generated interfaces and tracked files unchanged before this report |

The local portable-target commands cover the reusable library packages only. A previous full-workspace wasm-gc check failed on unsupported async entrypoint/filesystem symbols in CLI packages (169 errors); the CLI and filesystem integration remain native-only. The native Windows toolchain has emitted upstream `moonbitlang/async` C4005 `EINVAL` macro-redefinition diagnostics during a clean C rebuild. MoonBit strict checks/tests/build passed, and that dependency warning was not suppressed. ACL-denied behavior was not directly tested on this host. A concurrent path-replacement race remains documented because the filesystem API does not offer an open-with-no-follow handle.

## Scope acceptance review

| Approved design area | Status | Evidence / limit |
| --- | --- | --- |
| Three-file repeated-endpoint synthetic example | Pass | README example reports exactly one three-file start cluster; no diagnostics |
| Distinct-file threshold and duplicate tracks | Pass | Audit tests and below-threshold authored fixtures |
| Dateline, high-latitude, exact radius, empty/multi-segment and GPX 1.0/1.1 behavior | Pass | Geometry, parser and redaction tests; 142 native suite tests pass |
| Transitive/wide endpoint components | Pass | Adversarial chain tests and documented spread warning |
| Default coordinate/raw-value privacy | Pass | Text/JSON tests and integration assertions; explicit coordinate output is opt-in |
| Preview purity, explicit zone, no-overwrite writes, reparse | Pass | Library purity and CLI tests; three example outputs validated |
| Split tracks, routes/waypoints, metadata selection and opaque extensions | Pass with conservative refusal | Tests cover retained runs/removal; ambiguous opaque ownership is diagnosed instead of guessed |
| Malformed XML, DTD, encoding, namespace and resource limits | Partial | Deterministic diagnostics and adversarial tests; ACL-denied filesystem behavior not directly exercised |
| Native CLI and portable library packages | Pass | Fresh commands above; CLI remains native-only because of async filesystem target support |
| CI and stable-toolchain requirement | Partial / pending external evidence | Local default stable channel and workflow installer align; local workflow syntax and commands were verified; no hosted CI or exact Hackathon toolchain clause has been confirmed |
| README, reproducible examples, license and provenance | Pass | All documented examples run; root Apache-2.0; dependency and synthetic-data sources documented |

## Repository and provenance audit

- Local branch: `codex/trackshield-development`. Local `main` exists but points to an older commit; without a hosted repository there is no verifiable remote default branch.
- No Git remote is configured. After local completion, the sole GitHub call used the login-only identity endpoint; it returned `[redacted login]`, which does not match the required `Zcxssxx`. No repository was queried. No credentials, tokens, historical accounts, or other account data were requested or displayed. Repository creation, push, hosted CI and application submission remain gated until the active login matches.
- The 27 development commits preceding Task 17 are non-empty development/documentation changes; the local-readiness report and subsequent identity-gate status add two more substantive commits, for 29 total. All recorded author and committer identities are `Zcxssxx <Zcxssxx@users.noreply.github.com>`.
- Exact prescribed source-count command over tracked `.mbt` files: 41 files, 4,979 production lines, 3,845 test lines, 8,824 total. This exceeds the user's 3,000-line quality target without padding.
- Root `LICENSE` is Apache-2.0, an OSI-approved license. `THIRD_PARTY_NOTICES.md` records exact dependencies, versions, source URLs, licenses, and authored fixture provenance. No third-party code or test fixtures were copied.
- The CI file is `.github/workflows/test.yml`; YAML parsed locally with PyYAML 6.0.2, but no GitHub schema validation or hosted run occurred.

## Overall local status

The project implementation, local checks, examples, and review materials are complete. The default stable toolchain channel and supported local targets are verified. External confirmation remains pending for the charter/supplement; the actual GitHub repository, its default branch/contributors, hosted CI, and final application submission have not been performed during this local stage. Those are recorded as pending rather than inferred or presented as complete.
