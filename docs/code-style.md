# Luau and documentation conventions

Write code for the next human maintainer. Keep rule names close to game language, keep branches explicit, and separate pure decisions from effects. Format first-party Luau with StyLua; P01 pins its configuration and the lint/type tools.

## Names and structure

- `PascalCase.luau` for modules, `init.server.luau` / `init.client.luau` for minimal bootstraps, `camelCase` locals/functions, `PascalCase` exported type names.
- `--!strict` at the top of first-party modules and tests. Narrow untrusted values at boundaries. Document any isolated type escape and why a precise type is unavailable.
- Module tables are the default; use class-like tables only for objects with independent state/lifetimes. No inheritance hierarchy is required for weapons or services.
- Name units: `elapsedSeconds`, `radiusStuds`, `angleRadians`. Keep configuration values centralized and validated at startup. Avoid magic numbers and implicit global state.
- Prefer cohesive feature folders once a source area grows. Do not split trivial functions into separate files merely to satisfy a line-count rule.

## Documentation example

This illustrates the convention, not an implemented module:

```luau
--!strict
--[=[
    WeaponRules: pure server-side readiness checks shared by aircraft weapons.
    No engine access, network calls or yielding. Time is injected in seconds.
    Each weapon retains its own next-fire time across weapon selection changes.
]=]

local WeaponRules = {}

--[=[
    Reports whether this weapon's cooldown has ended before the round deadline.
    The caller separately validates role, ownership, ammunition and aim.
    All inputs are finite monotonic seconds. Returns false at the deadline.
    Does not mutate state or yield; switching weapons never changes these inputs.
]=]
function WeaponRules.canFire(
    nextFireAtSeconds: number,
    nowSeconds: number,
    deadlineSeconds: number
): boolean
    return nowSeconds < deadlineSeconds and nowSeconds >= nextFireAtSeconds
end

return WeaponRules
```

Use Luau block comments for module and API contracts; Moonwave-style tags may be added if generated API docs become useful, but a documentation generator is not required for MVP. Document exported records/unions and their invariants. For stateful objects, document construction, start/stop/destroy behavior, event ownership and idempotency.

Private functions need comments when they contain a non-obvious algorithm, timing rule, coordinate conversion, security assumption or cleanup requirement. Avoid comments that restate a name or syntax. Package READMEs explain responsibilities, allowed dependencies, public entrypoints and test locations.

## Tests and prose

Give every suite a short purpose/requirement header. Names describe observations such as “rejects a rocket hit at the round deadline” rather than “test 4.” Explain tolerances and fixture seeds. Group setup so the action and expected result remain easy to see.

Keep the player README cohesive: update current behavior in place, remove stale descriptions, and label unimplemented targets. Include one real, representative screenshot of current progress and a practical local setup/Rojo/play/test how-to. Keep advanced contributor details in the development guide. History, check outputs and feature-specific completion facts belong in plans, not a growing list of README announcements.
