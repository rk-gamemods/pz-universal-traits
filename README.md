# Universal Traits

Universal Traits is an independently developed single-player trait collection
for Project Zomboid Build 42.

The product consists of two required mods:

- `UT_CORE`: shared runtime infrastructure used by the trait implementations.
- `UniversalTraits`: the playable trait collection.

Enable both mods. `UniversalTraits` declares `UT_CORE` as a required dependency.

## Authorship and inspiration

This project was inspired by ideas found across the Project Zomboid
trait-modding community. It is an independent implementation, not a source fork
of an earlier trait mod. Trait behavior, identifiers, costs, balance,
interactions, runtime systems, tests, and packaging are maintained here.

No third-party mod source code or assets are distributed in the public
repository. Local reference copies used during private research are excluded
from Git. See `ATTRIBUTION.md` for the project attribution policy.

## Supported scope

- Project Zomboid Build 42
- `42.0` compatibility layout only
- Single-player only

Multiplayer support, backward compatibility, and save migration are outside the
current project scope.

## Repository layout

| Path | Purpose |
| --- | --- |
| `UT_CORE/` | Shared source, tests, and packaged release for the runtime library |
| `UniversalTraits/` | Trait source, translations, tests, and packaged release |
| `trait-deep-audit/` | Evidence-backed trait and runtime audit records |
| `tools/` | Deterministic analysis and verification helpers |
| `research/` | Authored research notes and manifests, excluding third-party source copies |

Source files under each mod are authoritative. Files under each mod's
`release/` directory are generated or synchronized package output.

## Tests

Run each suite from the repository root with a Lua interpreter:

```powershell
lua UT_CORE/test/run_tests.lua
lua UniversalTraits/test/run_tests.lua
```

The suites use standard Lua with mocked Project Zomboid APIs. Final runtime
validation still requires a full game relaunch on the supported Build 42
version.

## License

No open-source license has been granted. The repository is public for source
availability, review, and project collaboration.
