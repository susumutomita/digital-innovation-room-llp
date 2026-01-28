#!/usr/bin/env bash
set -euo pipefail

# End-to-end smoke test against a local anvil chain.
# Runs: deploy factory -> deploy mock token -> create engagement -> set split -> lock -> mint/approve/deposit -> distribute.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }
}

require anvil
require forge
require cast

ANVIL_PORT=${ANVIL_PORT:-8545}
RPC_URL="http://127.0.0.1:${ANVIL_PORT}"

# anvil default first key (deterministic)
PRIVATE_KEY=${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}

cleanup() {
  if [[ -n "${ANVIL_PID:-}" ]]; then
    kill "$ANVIL_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

anvil --port "$ANVIL_PORT" --silent &
ANVIL_PID=$!

# wait for RPC
for _ in $(seq 1 50); do
  if cast block-number --rpc-url "$RPC_URL" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

export RPC_URL
export PRIVATE_KEY

extract_addr() {
  # Grep first 0x + 40 hex.
  grep -Eo '0x[a-fA-F0-9]{40}' | head -n 1
}

# build once (silence lint notes)
forge build >/dev/null 2>&1

# Deploy factory
out_factory=$(./cli/engagement.sh deploy:factory)
FACTORY_ADDRESS=$(echo "$out_factory" | grep -E "Deployed to:" -A0 | extract_addr)
if [[ -z "$FACTORY_ADDRESS" ]]; then
  # fallback: first 0x40 in output
  FACTORY_ADDRESS=$(echo "$out_factory" | extract_addr)
fi
export FACTORY_ADDRESS

# Deploy mock token
out_token=$(./cli/engagement.sh deploy:mock-erc20 "Mock" "MOCK" 6)
TOKEN_ADDRESS=$(echo "$out_token" | grep -E "Deployed to:" -A0 | extract_addr)
if [[ -z "$TOKEN_ADDRESS" ]]; then
  TOKEN_ADDRESS=$(echo "$out_token" | extract_addr)
fi
export TOKEN_ADDRESS

ENGAGEMENT_ADMIN=$(cast wallet address --private-key "$PRIVATE_KEY")
export ENGAGEMENT_ADMIN

now=$(date +%s)
start=$now
end=$((now+3600))

# Create engagement
out_create=$(./cli/engagement.sh factory:create-engagement \
  "$ENGAGEMENT_ADMIN" \
  "$TOKEN_ADDRESS" \
  "$start" \
  "$end" \
  "https://example.com/metadata-local.json")

# We don't parse event logs here; compute address via eth_call on factory (works if nonce unchanged)
# Instead, read the EngagementCreated event from receipt logs using cast receipt.
create_tx=$(echo "$out_create" | awk '$1=="transactionHash"{print $2; exit}')
if [[ -z "$create_tx" ]]; then
  # fallback: first 32-byte hex
  create_tx=$(echo "$out_create" | grep -Eo '0x[a-fA-F0-9]{64}' | head -n 1)
fi
if [[ -z "$create_tx" ]]; then
  echo "Failed to capture create tx hash" >&2
  exit 1
fi

# Parse event topic for EngagementCreated(address indexed engagement,...)
# Topic0 = keccak256("EngagementCreated(address,address,address)")
# Parse EngagementCreated event from the tx receipt via JSON-RPC (wait until mined).
ENGAGEMENT_ADDRESS=$(python3 - "$RPC_URL" "$create_tx" <<'PY'
import json,sys,time,subprocess
RPC_URL=sys.argv[1]
tx=sys.argv[2]
TOPIC0="0xea36933885a748971ecbb94a1640d15cb83b0e0e4612df2dda22e993909dcb41".lower()
for _ in range(50):
    out=subprocess.check_output(["cast","rpc","--rpc-url",RPC_URL,"eth_getTransactionReceipt",tx])
    s=out.strip()
    if s==b"null":
        time.sleep(0.1)
        continue
    res=json.loads(out)
    for lg in res.get('logs',[]):
        topics=[t.lower() for t in lg.get('topics',[])]
        if topics and topics[0]==TOPIC0:
            t1=lg['topics'][1]
            print('0x'+t1[-40:])
            sys.exit(0)
    break
print('')
PY
)


if [[ -z "$ENGAGEMENT_ADDRESS" ]]; then
  echo "Failed to determine Engagement address" >&2
  exit 1
fi
export ENGAGEMENT_ADDRESS

# Set split (two recipients)
PRETTY=1 ./cli/engagement.sh engagement:set-split \
  0x000000000000000000000000000000000000dEaD,0x0000000000000000000000000000000000000001 \
  7000,3000 >/dev/null

# Lock
./cli/engagement.sh engagement:lock >/dev/null

# sanity: ensure we're hitting the proxy address
status=$(cast call --rpc-url "$RPC_URL" "$ENGAGEMENT_ADDRESS" "status()(uint8)")
[[ "${status%% *}" == "1" ]] || { echo "expected LOCKED status, got $status" >&2; exit 1; }

# Mint/approve/deposit
payer=$(cast wallet address --private-key "$PRIVATE_KEY")
./cli/engagement.sh token:mint "$payer" 100000000 >/dev/null
./cli/engagement.sh token:approve "$ENGAGEMENT_ADDRESS" 100000000 >/dev/null
./cli/engagement.sh engagement:deposit 100000000 >/dev/null

# Distribute
./cli/engagement.sh engagement:distribute >/dev/null

# Assert balances
b1=$(cast call --rpc-url "$RPC_URL" "$TOKEN_ADDRESS" "balanceOf(address)(uint256)" 0x000000000000000000000000000000000000dEaD)
b2=$(cast call --rpc-url "$RPC_URL" "$TOKEN_ADDRESS" "balanceOf(address)(uint256)" 0x0000000000000000000000000000000000000001)

[[ "$b1" == "70000000"* ]] || { echo "bad balance1: $b1" >&2; exit 1; }
[[ "$b2" == "30000000"* ]] || { echo "bad balance2: $b2" >&2; exit 1; }

echo "OK: e2e anvil flow passed"
