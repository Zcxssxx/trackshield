# October 2026 Hackathon submission readiness

Checked on 2026-10-26 against the [official October 2026 landing page](https://moonbitlang.github.io/Hackathon2026/). This checklist distinguishes what that page states from advice and our own quality targets. The formal charter and supplemental page were not readable through the available public-page retrieval, so this is not a substitute for their final wording.

## Official page: stated requirements and policies

- The October round's registration and project acceptance deadline is **2026-10-31**. The page does not show a cutoff time, time zone, or last-updated date in the content retrieved.
- October allows at most three submissions. The last valid submission or modification before approval is used; a rejected proposal may be revised.
- Qualification review is rolling. The page explains that the last valid submission or modification before approval determines the reviewed proposal.
- A team has at most three people. The team leader confirms team size and other members' GitHub IDs.
- The described application asks for participant/event information, a public repository, and a one-page project description. Exact form fields and the required file format for the one-page description are not stated in the retrieved page.
- Development is expected to remain visible in a public repository with continuing commits and project activity. Project acceptance calls for source code, a clear README, tests, and reproducible demonstration instructions.
- The project must use MoonBit as its primary implementation language, be publicly accessible, meet open-source requirements, and represent substantive new work where applicable. AI assistance is allowed; the participant remains responsible for explaining the goal, technical route, and quality.
- Participants are told to join the event group and use their GitHub ID as their group nickname; the page says this affects prize administration.

## Official page: recommendations

- The listed tool-library, data-processing, AI-application, and developer-tool directions are suggestions, not an exhaustive list.
- The page recommends a clear boundary, a real use case, and a deliverable that can be verified. Its FAQ says a project does not need to be large; reliability, documentation, and actual usability matter.

## Our quality goals (not presented as official rules)

- More than 3,000 meaningful MoonBit source lines without padding, a traceable history with more than ten substantive commits, strict warning-denying checks/tests, reusable APIs, examples, privacy/safety boundaries, and a local CI definition.
- Apache-2.0 at the repository root and documented dependencies/data provenance.
- TrackShield currently exceeds the size/history goals: 4,979 production lines plus 3,845 test lines across 41 tracked `.mbt` files, and 28 local commits including this readiness record.

## Pending confirmation

- The [formal charter](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd) and [supplemental event page](https://bxup9uklfcb.feishu.cn/wiki/KNrVwEVFziPHiGkQtwhc6w3gndd) could not be retrieved. Their update timestamps, exact submission materials and fields, review and revision rules, exact license clauses, Mooncakes publication, CI, and toolchain-version requirements are `待确认`.
- The landing-page deadline's exact time and time zone are `待确认`.
- The default `moon upgrade` channel (without `--dev`) completed successfully on 2026-10-26 and resolved to `moonc v0.10.17+d971670cd` (2026-10-23); the `--dev` option is specifically for the development toolchain. The official [updates page](https://www.moonbitlang.com/updates) lists v0.10.14 (2026-09-21) as its newest monthly announcement, so that index is behind the installer channel. Project CI uses the official installer default channel and prints the version it resolves. The Hackathon's own toolchain clause remains `待确认`.
- No event application has been submitted. No public repository, public default branch, hosted CI result, or Mooncakes publication is claimed.

## One-page project description draft

### TrackShield: offline GPX collection privacy audit

TrackShield is a local-first MoonBit command-line tool and reusable library for people who review outdoor activity exports before sharing them. A collection of GPX tracks can reveal recurring start or end points even when individual activities have been trimmed, while file metadata can expose names, author fields, timestamps, links, and extension presence. TrackShield reports these as review clues; it does not identify a home, workplace, or person, and it does not certify anonymity.

The `audit` command reads GPX 1.0/1.1 files without network access, checks repeated track endpoints across distinct files, and reports a documented set of metadata categories. Text and JSON output are deterministic and omit exact centers and raw values by default. The `redact` command accepts only a user-entered center and radius. It previews first; writing requires explicit confirmation and a new output directory. It revalidates outputs and refuses transformations where opaque content cannot be assigned safely.

The project is implemented primarily in MoonBit. It has a native CLI and a reusable library whose analysis packages build and test on native, wasm, wasm-gc, and JavaScript targets. On the current local toolchain, strict native tests pass 142/142; portable-library tests pass 113/113 on each non-native target. The checked-in three-file GPX example is synthetic and demonstrates a repeated-start finding. Root license: Apache-2.0. Dependency versions and provenance are documented in `THIRD_PARTY_NOTICES.md`.

AI assistance disclosure: Codex assisted with planning, implementation, tests, and documentation. The participant selected the project and constraints, reviewed design decisions, and is responsible for understanding and validating the submitted work.

Application fields not yet filled: participant/team details, public repository URL, actual form-specific fields, and the organizer's required one-page file format. This draft is prepared locally and has not been submitted.
