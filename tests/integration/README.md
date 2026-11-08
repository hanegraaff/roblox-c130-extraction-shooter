# Lifecycle integration suite

`Lifecycle.spec.luau` covers P01/R01/R15 by composing the actual shared lifecycle controller with controlled resource adapters. It checks two start/stop cycles, idempotency, partial-start rollback and retry. Counter-based adapters model owned listeners/tasks; they do not prove engine signal or scheduler behavior.

Run `lune run scripts/run_tests.luau integration` from the root after setup, with Rokit tools on PATH. The Studio server wrapper also registers these same cases against the actual mapped module. Separate Studio specs test engine-owned bootstrap and GUI resources.

Future service suites should connect real services to controlled transport/time/world boundaries. Use real engine suites whenever the claim depends on Instances, raycasts or replication.
