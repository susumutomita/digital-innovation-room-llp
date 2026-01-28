.PHONY: deps build test test-unit test-cli test-anvil lint fmt

FOUNDRY_FUZZ_RUNS ?= 2000

# Install deps if missing (safe to rerun)
deps:
	@test -d lib/forge-std || forge install --no-git foundry-rs/forge-std
	@test -d lib/openzeppelin-contracts/contracts || forge install --no-git OpenZeppelin/openzeppelin-contracts@v5.0.2

build: deps
	forge build

fmt:
	forge fmt

lint: deps
	forge fmt --check
	@command -v shellcheck >/dev/null 2>&1 && shellcheck -x cli/*.sh script/*.sh || echo "shellcheck not installed (skipping)"
	@bash -n cli/engagement.sh

test-unit: deps
	forge test --fuzz-runs $(FOUNDRY_FUZZ_RUNS)

test-cli:
	@command -v bats >/dev/null 2>&1 || (echo "bats not installed" && exit 1)
	bats test/cli.bats

test-anvil: deps
	bash script/e2e_anvil.sh

# one command to run all local checks
test: lint build test-unit test-cli test-anvil
