# Pure rule suites

`Config.spec.luau`, `Validation.spec.luau` and `RateLimit.spec.luau` cover P01/R01/R13 finite inputs, exact boundaries, malformed/oversized payloads and injected-time token accounting. Rejected calls must preserve input or rate state; valid requests still succeed afterward.

`MapRules.spec.luau` adds P02/R05 circle configuration, finite/mismatched geometry settings, inclusive disk boundaries and sampled future-orbit positions. It is pure math/configuration evidence; it does not spawn an aircraft or prove world clearance. The current unit suite has 14 cases.

Run `lune run scripts/run_tests.luau unit` from the repository root after setup, with Rokit tools on PATH. Each spec returns a function accepting `(test, actualModule)`; it does not copy production rules. The standalone runner discovers these files and loads filesystem modules. The Studio server wrapper registers the same cases with TestEZ using mapped ModuleScripts, proving dependency loading in both runtimes.

Add deterministic gameplay rule cases as their plans implement them. Inject clocks/randomness and test observable boundaries rather than private implementation details.
