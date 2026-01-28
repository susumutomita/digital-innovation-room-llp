# Dev / Local testing

From `contracts/`:

## One command

```bash
make test
```

What it does:
- format check + shell lint
- build
- unit + fuzz tests
- CLI unit tests (bats)
- local anvil end-to-end smoke test

## Prereqs

- Foundry (`forge`, `cast`, `anvil`)
- Make
- `bats` (for CLI tests)
  - macOS: `brew install bats-core`
  - Ubuntu/Debian: `sudo apt-get install -y bats`
- `shellcheck` (optional locally; CI installs it)
  - macOS: `brew install shellcheck`
  - Ubuntu/Debian: `sudo apt-get install -y shellcheck`

## Useful targets

```bash
make lint
make test-unit
make test-cli
make test-anvil
```
