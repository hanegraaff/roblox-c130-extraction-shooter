# Pure rule suites

`Config.spec.luau`, `Validation.spec.luau` and `RateLimit.spec.luau` cover P01/R01/R13 finite inputs, exact boundaries, malformed/oversized payloads and injected-time token accounting. Rejected calls must preserve input or rate state; valid requests still succeed afterward.

Run `lune run scripts/run_tests.luau unit` from the repository root after setup, with Rokit tools on PATH. Each spec returns a function accepting `(test, actualModule)`; it does not copy production rules. The standalone runner discovers these files and loads filesystem modules. The Studio server wrapper registers the same cases with TestEZ using mapped ModuleScripts, proving dependency loading in both runtimes.

Add deterministic gameplay rule cases as their plans implement them. Inject clocks/randomness and test observable boundaries rather than private implementation details.
