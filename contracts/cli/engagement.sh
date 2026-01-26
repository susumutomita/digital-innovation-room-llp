#!/usr/bin/env bash
set -euo pipefail

# Simple CLI for Engagement / EngagementFactory using Foundry cast.
#
# Requirements:
#   - foundry (cast)
#   - env: RPC_URL, PRIVATE_KEY
# Optional:
#   - FACTORY_ADDRESS
#   - ENGAGEMENT_ADDRESS
#   - TOKEN_ADDRESS

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing env $name" >&2
    exit 1
  fi
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") <command> [args]

Env:
  RPC_URL (required)
  PRIVATE_KEY (required)
  FACTORY_ADDRESS (required for create)
  ENGAGEMENT_ADDRESS (required for set-split/lock/deposit/distribute)
  TOKEN_ADDRESS (required for approve/mint/deposit)

Commands:
  help

  # Deploy helpers
  deploy:mock-erc20 <name> <symbol> <decimals>
  deploy:factory
  factory:create-engagement <adminAddress> <tokenAddress>

  # Engagement ops
  engagement:set-split <recipientsCsv> <sharesBpsCsv>
  engagement:lock
  engagement:cancel

  # Token helpers
  token:mint <to> <amount>
  token:approve <spender> <amount>

  # Payments
  engagement:deposit <amount>
  engagement:distribute

Examples:
  export RPC_URL=... PRIVATE_KEY=...
  ./cli/engagement.sh deploy:factory
  export FACTORY_ADDRESS=0x...
  ./cli/engagement.sh deploy:mock-erc20 Mock MOCK 6
  export TOKEN_ADDRESS=0x...
  ./cli/engagement.sh factory:create-engagement 0xAdmin $TOKEN_ADDRESS
  export ENGAGEMENT_ADDRESS=0x...
  ./cli/engagement.sh engagement:set-split 0xR1,0xR2 7000,3000
  ./cli/engagement.sh engagement:lock
  ./cli/engagement.sh token:mint 0xPayer 100000000
  # run approve+deposit from the payer key
  ./cli/engagement.sh token:approve $ENGAGEMENT_ADDRESS 100000000
  ./cli/engagement.sh engagement:deposit 100000000
  ./cli/engagement.sh engagement:distribute
USAGE
}

cast_send() {
  require_env RPC_URL
  require_env PRIVATE_KEY
  cast send --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" "$@"
}

cast_call() {
  require_env RPC_URL
  cast call --rpc-url "$RPC_URL" "$@"
}

abi_path() {
  local file="$1"
  echo "$OUT_DIR/$file"
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  help|-h|--help)
    usage
    ;;

  deploy:mock-erc20)
    name="${1:?name}"; symbol="${2:?symbol}"; decimals="${3:?decimals}"
    # Deploy by sending raw bytecode (cast create)
    require_env RPC_URL
    require_env PRIVATE_KEY
    cast create --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" \
      "$OUT_DIR/MockERC20.sol/MockERC20.json" \
      --constructor-args "$name" "$symbol" "$decimals"
    ;;

  deploy:factory)
    require_env RPC_URL
    require_env PRIVATE_KEY
    cast create --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" \
      "$OUT_DIR/EngagementFactory.sol/EngagementFactory.json"
    ;;

  factory:create-engagement)
    require_env FACTORY_ADDRESS
    admin="${1:?adminAddress}"; token="${2:?tokenAddress}"
    cast_send "$FACTORY_ADDRESS" "create(address,address)(address)" "$admin" "$token"
    echo "Tip: parse the logs to get the new Engagement address (EngagementCreated event)."
    ;;

  engagement:set-split)
    require_env ENGAGEMENT_ADDRESS
    rec_csv="${1:?recipientsCsv}"; shares_csv="${2:?sharesBpsCsv}"

    IFS=',' read -r -a rec <<< "$rec_csv"
    IFS=',' read -r -a sh <<< "$shares_csv"

    if [[ ${#rec[@]} -ne ${#sh[@]} ]]; then
      echo "recipients and shares length mismatch" >&2
      exit 1
    fi

    # Build JSON arrays for cast
    rec_json="["; sh_json="["
    for i in "${!rec[@]}"; do
      [[ $i -gt 0 ]] && rec_json+="," && sh_json+=","
      rec_json+="\"${rec[$i]}\""
      sh_json+="${sh[$i]}"
    done
    rec_json+="]"; sh_json+="]"

    cast_send "$ENGAGEMENT_ADDRESS" "setSplit(address[],uint256[])" "$rec_json" "$sh_json"
    ;;

  engagement:lock)
    require_env ENGAGEMENT_ADDRESS
    cast_send "$ENGAGEMENT_ADDRESS" "lock()"
    ;;

  engagement:cancel)
    require_env ENGAGEMENT_ADDRESS
    cast_send "$ENGAGEMENT_ADDRESS" "cancel()"
    ;;

  token:mint)
    require_env TOKEN_ADDRESS
    to="${1:?to}"; amount="${2:?amount}"
    cast_send "$TOKEN_ADDRESS" "mint(address,uint256)" "$to" "$amount"
    ;;

  token:approve)
    require_env TOKEN_ADDRESS
    spender="${1:?spender}"; amount="${2:?amount}"
    cast_send "$TOKEN_ADDRESS" "approve(address,uint256)" "$spender" "$amount"
    ;;

  engagement:deposit)
    require_env ENGAGEMENT_ADDRESS
    amount="${1:?amount}"
    cast_send "$ENGAGEMENT_ADDRESS" "deposit(uint256)" "$amount"
    ;;

  engagement:distribute)
    require_env ENGAGEMENT_ADDRESS
    cast_send "$ENGAGEMENT_ADDRESS" "distribute()"
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    usage
    exit 1
    ;;
esac
