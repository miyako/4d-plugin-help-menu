# Manual source releases

## Authority and migration evidence

The API default branch and symbolic `refs/remotes/origin/HEAD` were both
`master` at intake (`9afa060525167f7ac657798506e302157ded4580`).
The original committed Bump was manual; the original Build & Release had
only tag-push and manual triggers, not branch-push or pull-request triggers.
No native workflow is dispatched by this migration.

The header of the original `.github/workflows/bump-version.yml` explicitly
coordinates `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, and existing
plist version fields. This overrides its buggy marketing-first body.
`git log --follow -- .github/workflows/bump-version.yml` traces that policy
to `8fe7c605ca591ac34294771b39ec8eb2260ff9c6`; there is no later policy change.
The six marketing and three current-project assignments are all `2.0.1`.
The source `Info.plist` references `$(MARKETING_VERSION)` and has no
`CFBundleVersion`; the absent key must remain absent. The only source
localization is `English.lproj/InfoPlist.strings`, whose two version-bearing
values already agree at `2.0.1`. No intake increment or drift repair is needed.
The independent prebuilt bundle under `test/Plugins` is not version authority
and is never changed by Bump or this migration.

Xcode's Default configuration builds the Help Menu target, links
`Cocoa.framework`, and copies the source localization through its Resources
phase. Its CopyFiles phase has `dstSubfolderSpec = 7` and copies
`manifest.json` and `constants.xlf` to `Contents/Resources`.
The Windows Release/x64 OutDir is exactly
`test\plugins\Help Menu.bundle\contents\windows64\`; Windows treats that as
the canonical `test/Plugins/Help Menu.bundle/Contents/Windows64` path.
CI retains the v143/Windows SDK 10.0 overrides, macOS 11.5 deployment
override, universal arm64/x86_64 build, signing, both notarizations, and
DMG stapling. It does not execute the project's Deployment-only signing
shell phase, because it builds Default.

## Operations

Run **Bump version** manually on a branch, choosing patch, minor, or major.
It checks out the immutable dispatch `github.sha`, requires a clean checkout
and that exact selected remote branch head, validates every source version,
then commits only the three source metadata files that actually changed.
It preserves build-variable references, absent optional fields, file modes,
BOMs, and each original CR/LF/CRLF newline. Its generated commit carries
`Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>`.
It creates no tag, release, build, or dispatch.

The executable `.github/scripts/bump-hooks/pre-push` is mandatory at both
preparation and push time. The nonforce branch push disables followed tags
both in configuration and on the command line. The advertised update must
be exactly one update from the selected old SHA to literal new HEAD on the
selected branch, with that old SHA as its sole direct parent. Advance,
rewind, deletion, and an already-identical result all abort rather than
silently report success.

Run the independent workflow named exactly **Build** manually after Bump.
It has zero custom inputs (the standard GitHub ref picker remains part of
GitHub's dispatch UI). Every job checks out `github.sha`; there is no custom
branch or tag selector. It derives strict `X.Y.Z`, `vX.Y.Z`, and asset names
from the selected source. Versions with leading zeros, suffixes, drift,
duplicate plist/localization keys, or duplicate project assignments fail
before writes. Assignment-like comments and strings are not authority.
Build can run on any selected ref without Bump.

Only exact native outputs are invalidated: the Windows Release/x64 output,
known intermediates, macOS executable/signature, and copied source plist and
localization. Other committed resources, Windows files, dependency dylibs,
and framework symlinks are preserved. Cleanup errors fail. Built plist and
localized metadata must match the selected source, including UTF-16 and
binary localization output. Native verification requires exact `arm64` and
`x86_64` tokens rather than CPU-subtype substrings, retains the original
plugin i386 exclusion, and verifies runtime dylibs independently.

## Create-only publication and recovery

All branches share constant `release-publication` concurrency with
`cancel-in-progress: false`. Before native work, and again after all
build/sign/notary/staple gates, authenticated release-list requests paginate
through every page, including drafts, and reject any matching tag. Exact
remote tag absence is also required. Authentication, API 404, network,
malformed responses, and errors on later pages abort; none means "absent."

Publication POSTs one new `refs/tags/vX.Y.Z` at the selected immutable SHA,
verifies that remote tag, then separately POSTs one new public,
nonprerelease release with explicit tag, name, target, body and draft flags.
ZIP and DMG uploads use only that newly returned release ID. There is no
reuse, PATCH, DELETE, clobber, rollback, mutation retry, generated release
notes, or release-with-assets shortcut.

If publication fails, earlier successful tag/release/assets deliberately
remain. The error reports partial publication and requires manual recovery.
Inspect the existing remote tag, release (including drafts), and uploaded
assets before deciding what to do. Do not retry Build for that same source
version: absence checks will reject it. Either manually resolve the partial
publication with appropriate authorization, or use Bump to prepare a new
source version and run Build on that new commit. This migration itself
does not create production tags/releases or dispatch native workflows.

## Pinned prior art and offline checks

Complete workflows, helpers, hooks, and tests were fetched and inspected at:

| Repository | Immutable commit |
|---|---|
| `miyako/4d-plugin-native-encoding-detection` | `c42ca565857f674bde5ea6ed3435c87375eda4a7` |
| `miyako/4d-plugin-file-information` | `19848973601acfd3a2b5070230fa40cdc7e4edb2` |
| `miyako/4d-plugin-common-string-algorithm` | `2606a68201866ec9fcbb38b51462d79215f504ef` |
| `miyako/4d-plugin-window-button` | `3f14facb9aaaaff0e22eeb8e07531163680c3a8a` |
| `miyako/4d-plugin-raw-picture-data` | `8144537fdc8dcc3d0c053dfe97aff0a8c0c3a6f9` |
| `miyako/4d-plugin-PRNG` | `522f62e1e9f388be0f3f226c1d4c39362dad2491` |

PRNG supplies the coordinated helper base, incorporating raw-picture-data's
lexical inline-duplicate check and PRNG's offset-filtered comment-safe
rewrite. File Information supplies the native resource/encoding regression
base. The other pinned examples were inspected for policy and lifecycle
differences; their independent-build policies are not imported here.
All repository-specific counts, paths, optional keys, and native gates are
adapted to Help Menu rather than inferred from a template.

Run `actionlint .github/workflows/*.yml` and
`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s .github/tests -v`.
The full suite also runs in a disposable local Git/bare-origin copy that
has actually completed the guarded Bump helper. Fixture versions derive
from source, not a hard-coded intake version. Native shell tests extract
the actual workflow blocks and use closed-PATH native-tool stubs;
PowerShell tests exercise cleanup and exact output normalization without
MSBuild, 4D, signing, or notarization.
