# Native ownership regression

Run `python3 .github/tests/test_ownership.py` on macOS with Apple clang.
This builds the actual entry, all four wrapper implementations, the JSON
helper, and the **complete unchanged** bundled `4DPluginAPI.c`. It sets
`gCall4D` to a synthetic engine callback, not replacements for the SDK APIs.
No AppKit framework is linked: the entry sees the local inert Cocoa shim.
The actual exported `FourDPackex` dispatcher is invoked only with synthetic
parameters and fake application/menu objects. No real menu, help system,
browser, URL opening, 4D database, signing, packaging or release is executed.
Existing release-script tests likewise use synthetic tools and repositories.

## Inventory and reachability

Audited baseline: `f0412603c2096c73d3a5287c1af8397ada2b95f2`.
The complete tracked native inventory is:

| Surface | Reachability and ownership findings |
|---|---|
| `4DPlugin-Help-Menu.cpp`, `.h` | Both projects compile this entry. `PluginMain` dispatches startup/exit and selectors 1/2 through `PA_RunInMainProcess`; both manifest commands use Longint only. macOS creates/releases an independent empty menu, retained by its application property. No PA string/array output. Legacy Windows startup reads `PA_GetApplicationFullPath` for hosts older than 16; ownership of that SDK output is deferred, not guessed. |
| `support/4DPlugin-JSON.cpp`, `.h` | Dormant: neither project compiles or includes these helpers. All functions inspected, not just exported signatures. String setters already use Undefined destinations and clear independently allocated values after object-property copy. Scalar getters leaked successful owned results, as did object/collection type mismatches; failed reads inspected potentially uninitialized values. Fixed without clearing successful object/collection owning handoffs. Stringify borrows/detaches input synchronously and clears the owning successful return; fixed raw-kind-0 command allocation failure handling. No first-party JSON Parse call exists. Picture setter input ownership is deferred: it shallow-aliases the caller's picture then clears the variable, but no repository caller establishes whether the input is transferred or borrowed. |
| `4D Plugin API/Classes/ARRAY_TEXT.cpp`, `.h` | Dormant first-party wrapper, excluded from both projects. Input/append operations copy UTF-16 into C++ strings before any output mutation; each normal output allocation is independent and transferred once. No post-transfer disposal. Normal replacement/shrink/clear passes. See deferred creation/rejection boundaries below. |
| `4D Plugin API/Classes/C_TEXT.cpp`, `.h` | Dormant wrapper. Copies borrowed inputs into independent C++ strings; outputs use content setters, not descriptor transfers. Cocoa string/path helpers use retained copy/create results and release them; no URL is opened. Noncopyable owner. |
| `4D Plugin API/Classes/C_BLOB.cpp`, `.h` | Dormant byte wrapper. Text/hex/base64 helpers use independent C++ storage. Not a CPicture wrapper; no CPicture family is tracked. Legacy BLOB replacement disposes the original handle before allocating; this non-string failure boundary is deferred below. |
| `4D Plugin API/Classes/C_LONGINT.cpp`, `.h` | Dormant scalar wrapper, no native string ownership. |
| `4D Plugin API/Classes/C_TYPES.h` | Dormant wrapper type aliases and platform includes only. Raw-owner ARRAY_TEXT/C_BLOB wrappers have no in-repository copy call sites; this audit does not certify external copying. |
| `4D Plugin API/4DPluginAPI.c`, `.h`, `Flags.h`, `PrivateTypes.h`, `PublicTypes.h`, `EntryPoints.h` | Actual bundled SDK boundary, compiled by both projects; reviewed for first-party API usage and shim contracts, never edited. Not an upstream SDK ownership repair. |
| `4D Plugin API/4DPluginAPI.def` | Windows export is `FourDPackex`; same SDK export leads to the actual `PluginMain`. |
| `manifest.json`, bundled resource manifest, `Help Menu.vcxproj`, `.filters`, `.sln`, Xcode project/scheme | Both manifests declare exactly `HELP SET ENABLED(&L)` and `HELP Get enabled:L`. Both projects compile only entry + SDK; no wrapper/helper source is pulled in transitively. Include search paths alone do not compile dormant sources. The Xcode Deployment phase signs/packages; it is not run. Both GitHub workflows are manual-only. |

No third-party native library source is tracked; the test dylib/plugin
binaries and real test database are not modified or executed.

## Bundled SDK provenance and contracts

`4DPluginAPI.c` Git blob:
`62f745e91d81ef2c3c901c656ea8e175d3b173e8`.
The file history traces through the root move
`8fe7c605ca591ac34294771b39ec8eb2260ff9c6`, refactoring
`0c83fc6622edb6f602af5698595d0e61f84bcfc1`, and original mac version
`981c0ca721c9636b297f2c0dcbc56ce19c4a5282`. No SDK download URL, pinned
upstream commit, package lock, or independently verified upstream release
identity is provided. The source's v14 and header's v13 comments are not
upstream provenance. The root-move commit identifies the dormant JSON,
C_TYPES, C_TEXT and C_LONGINT copies as coming from
`4d-plugin-migration` commit `de605ad`; this is recorded repository history,
not independent upstream SDK verification.

Contracts are derived from this actual implementation:

- `PA_SetStringInArray` (4933-4948) accepts exactly Unicode array, non-null
  data, index in **0..count**, non-null input descriptor. It disposes the
  old slot then shallow-assigns the incoming descriptor. Rejection retains
  the caller owner. Getter (4738-4755) aliases the borrowed element.
- `PA_SetStringVariable` (4254-4259) is a shallow descriptor assignment.
  `PA_CreateVariable(Unistring)` allocates an initial empty owner; Undefined
  does not. `PA_SetUnistring`/`PA_ReturnString` call the engine content
  setter instead of the array transfer implementation.
- `PA_GetObjectProperty` (636-651) explicitly says clear after use. On error
  its local output can remain uninitialized: check `PA_GetLastError`
  immediately, before kind lookup or cleanup. Successful object/collection
  returned references remain owning until the consumer disposes them.
- `PA_ExecuteCommandByID` (5778-5815) returns raw zero on argument-handle
  failure; `UnifyVarKind(0)` normalizes to Unistring. Method-by-ID failure
  instead initializes Undefined. The shim rejects string access/cleanup of
  the raw sentinel. Command parameters are borrowed for a synchronous call;
  destroying their pointer handle does not destroy the arguments.
- String lengths are UTF-16 **units**, allocation capacities are
  `(units + 1) * sizeof(PA_Unichar)` **bytes**, and terminating zero is not
  included in the length. UTF-8 conversion results are byte counts. The
  shim uses packed SDK structs without passing packed pointer fields by
  reference into STL containers. All sanitizers, including alignment, stay
  enabled.

## Evidence and bounds

The same harness can use an immutable extracted source tree:

```sh
git archive f0412603c2096c73d3a5287c1af8397ada2b95f2 | tar -x -C /existing/scratch/baseline
OWNERSHIP_SOURCE_ROOT=/existing/scratch/baseline python3 .github/tests/test_ownership.py
```

Only the source root changes: the final harness is unchanged. The baseline
fails the named `scalar`, `mismatch`, `handoffs` owner-balance assertions,
`failed-get` invalid enum inspection under UBSan, and
`command-handle-failure` invalid raw-kind string access assertion. The fix
passes the full 88-case matrix: eleven modes, ASCII/BMP/supplementary/empty
fixtures, allocated/null empty representations. The allocated empty is
necessary to detect leaks hidden by the null-empty case.

Successful string reads/stringify assert literal fixture UTF-8 bytes; native strings
assert exact UTF-16 lengths/content and termination. Array tests exercise
independent transfers, borrowed copies surviving original cleanup,
replacement, shrink, final clear and each setter rejection predicate.
Scalar content setters retain independent outputs after input mutation;
`PA_ReturnString` uses the real SDK's content-setter forwarding. Repeated
JSON setters preserve exact native content without leaking initial empties.
Object/collection handoffs survive source-owner cleanup, then consumers
release them. Getter failures write poison instead of a valid owner;
command failures leave output unchanged and never inspect/clear an invalid
sentinel. Every successful case ends with zero tracked string allocations,
handles and object/collection references under ASan/UBSan. macOS LSan is
unavailable; explicit balances replace leak detection for modeled owners.

### Deferred, not certified

- Dormant `ARRAY_TEXT::toParamAtIndex` creates an array for Undefined and
  publishes the type before validating allocation. A missing data handle
  then rejects assignments without releasing new string owners. The void
  wrapper has no established error return/notification channel or live
  call site to update safely. A partial guard that silently returns or
  publishes an empty success is not an acceptable fix. This boundary is
  deferred for an explicit failure-reporting API decision; normal-array
  passing tests do not certify it.
- The SDK's `PA_ResizeArray` updates count even after resize allocation
  failure (4610). This can corrupt the count/capacity relationship. The
  harness does **not** inject resize OOM or claim to fix/certify it; the SDK
  remains unchanged.
- Dormant CBytes BLOB output destroys its old handle before new-handle
  success, leaving a dangling caller handle on failure. This is outside the
  bounded string fix and likewise needs an explicit failure contract.
- SDK-only application-path/picture-data outputs, pointer metadata, and the
  unused picture setter's caller contract are not assigned speculative
  ownership or cleanup.
- No Windows execution, real 4D host execution, AppKit menu test, broad OOM
  certification, or reproduction of the original Windows Poppler crash.
  This is source-derived synthetic ownership evidence, not host ABI
  certification.
