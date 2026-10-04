# Windows integration tests

The Windows jobs exercise the real non-interactive bootstrap and update paths under both the normal execution policy and `AllSigned`.

- `assert-migration.ps1` verifies recovery from broken managed links without modifying unrelated broken links.
- `assert-fonts.ps1` verifies that every downloaded baseline font exists in the current-user Fonts directory and has a matching HKCU font registration.
- `assert-state.ps1` validates the normal-policy runtime state.
- `assert-allsigned.ps1` validates signatures, trusted certificate state, modules, and profile startup under `AllSigned`.

Scripts executed after `AllSigned` becomes effective must run through the repository CMD signing bridge.
