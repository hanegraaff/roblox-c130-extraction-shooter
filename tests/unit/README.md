# Pure rule suites

`Config.spec.luau`, `Validation.spec.luau` and `RateLimit.spec.luau` cover P01/R01/R13 finite inputs, exact boundaries, malformed/oversized payloads and injected-time token accounting. Rejected calls must preserve input or rate state; valid requests still succeed afterward.

`MapRules.spec.luau` adds P02/R05 circle configuration, finite/mismatched geometry settings, inclusive disk boundaries and sampled future-orbit positions. It is pure math/configuration evidence; it does not spawn an aircraft or prove world clearance. RoleService.spec.luau adds production population boundaries, exact role counts, seeded rotation and bounded seed validation. RoundRules.spec.luau covers legal phases, exact expiry, mutual destruction and noncompetitive empty-server cleanup. AircraftRules.spec.luau adds six P04/R05/R06 cases for periodicity/negative phase wrap, tangent/altitude/perimeter geometry, invalid settings/derived overflow, finite distinct FOVs and inclusive aim boundaries. The current unit suite has 30 cases.

Run `lune run scripts/run_tests.luau unit` from the repository root after setup, with Rokit tools on PATH. Each spec returns a function accepting `(test, actualModule)`; it does not copy production rules. The standalone runner discovers these files and loads filesystem modules. The Studio server wrapper registers the same cases with TestEZ using mapped ModuleScripts, proving dependency loading in both runtimes.

Authoritative RoleService/RoundRules load from the server package in Lune and Studio; they are not replicated for testing. Add deterministic gameplay rule cases as their plans implement them. Inject clocks/randomness and test observable boundaries rather than private implementation details.
