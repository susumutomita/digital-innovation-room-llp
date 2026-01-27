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

  # Info
  engagement:status

  # Deploy helpers
  deploy:mock-erc20 <name> <symbol> <decimals>
  deploy:factory
  factory:create-engagement <adminAddress> <tokenAddress> <startAt> <endAt> <metadataURI>

  # Engagement ops
  engagement:set-split <recipientsCsv> <sharesBpsCsv>
    # optional env: PRETTY=1 (print preview + sum bps)
  engagement:set-metadata-uri <metadataURI>
  engagement:set-match-window <startAt> <endAt>
  engagement:finalize
  engagement:lock
  engagement:cancel
  engagement:status

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
  ./cli/engagement.sh factory:create-engagement 0xAdmin $TOKEN_ADDRESS $(date +%s) $(($(date +%s)+172800)) https://example.com/meta.json
  export ENGAGEMENT_ADDRESS=0x...
  ./cli/engagement.sh engagement:set-split 0xR1,0xR2 7000,3000
  ./cli/engagement.sh engagement:lock
  # or wait until endAt and call:
  # ./cli/engagement.sh engagement:finalize
  ./cli/engagement.sh token:mint 0xPayer 100000000
  # run approve+deposit from the payer key
  ./cli/engagement.sh token:approve $ENGAGEMENT_ADDRESS 100000000
  ./cli/engagement.sh engagement:deposit 100000000
  ./cli/engagement.sh engagement:distribute
USAGE
}

EXPLORER_BASE_DEFAULT="https://amoy.polygonscan.com"

explorer_base() {
  # Allow override via env. Fallback to Amoy Polygonscan.
  echo "${EXPLORER_BASE:-$EXPLORER_BASE_DEFAULT}"
}

print_tx_link() {
  local tx="$1"
  [[ -z "$tx" ]] && return 0
  echo "Explorer: $(explorer_base)/tx/$tx"
}

print_addr_link() {
  local addr="$1"
  [[ -z "$addr" ]] && return 0
  echo "Explorer: $(explorer_base)/address/$addr"
}

extract_tx_hash() {
  # Extract tx hash from common cast/forge outputs.
  # - cast send receipt contains: transactionHash      0x...
  # - forge create contains: Transaction hash: 0x...
  grep -Eo '0x[a-fA-F0-9]{64}' | head -n 1
}

cast_send() {
  require_env RPC_URL
  require_env PRIVATE_KEY

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "[dry-run] cast send --rpc-url $RPC_URL --private-key <redacted> $*"
    return 0
  fi

  # Capture output to print explorer link.
  local out
  out=$(cast send --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" "$@")
  echo "$out"
  local tx
  tx=$(echo "$out" | extract_tx_hash || true)
  print_tx_link "$tx"
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
    require_env RPC_URL
    require_env PRIVATE_KEY
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      echo "[dry-run] forge create --broadcast --rpc-url $RPC_URL --private-key <redacted> src/MockERC20.sol:MockERC20 --constructor-args '$name' '$symbol' '$decimals'"
      exit 0
    fi
    # Use forge create (cast no longer has `create` subcommand)
    out=$(forge create --broadcast --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" \
      "src/MockERC20.sol:MockERC20" \
      --constructor-args "$name" "$symbol" "$decimals")
    echo "$out"
    tx=$(echo "$out" | extract_tx_hash || true)
    print_tx_link "$tx"
    # small celebratory, low-noise
    [[ -n "$tx" ]] && echo "DEPLOY SUCCESS. MAY YOUR GAS BE LOW."
    ;;

  deploy:factory)
    require_env RPC_URL
    require_env PRIVATE_KEY
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      echo "[dry-run] forge create --broadcast --rpc-url $RPC_URL --private-key <redacted> src/EngagementFactory.sol:EngagementFactory"
      exit 0
    fi
    # Use forge create (cast no longer has `create` subcommand)
    out=$(forge create --broadcast --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" \
      "src/EngagementFactory.sol:EngagementFactory")
    echo "$out"
    tx=$(echo "$out" | extract_tx_hash || true)
    print_tx_link "$tx"
    [[ -n "$tx" ]] && echo "DEPLOY SUCCESS. MAY YOUR GAS BE LOW."
    ;;

  factory:create-engagement)
    require_env FACTORY_ADDRESS
    admin="${1:?adminAddress}"; token="${2:?tokenAddress}"
    startAt="${3:?startAt}"; endAt="${4:?endAt}"; metadataURI="${5:?metadataURI}"
    cast_send "$FACTORY_ADDRESS" "create(address,address,uint64,uint64,string)(address)" "$admin" "$token" "$startAt" "$endAt" "$metadataURI"
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

    # Build array literals that cast understands (no quotes around addresses).
    # Also trim surrounding whitespace from CSV-derived values.
    rec_lit="["; sh_lit="["
    sum_bps=0
    for i in "${!rec[@]}"; do
      [[ $i -gt 0 ]] && rec_lit+="," && sh_lit+="," 

      # trim leading/trailing whitespace (spaces/tabs/newlines)
      trimmed_rec="${rec[$i]#${rec[$i]%%[![:space:]]*}}"
      trimmed_rec="${trimmed_rec%${trimmed_rec##*[![:space:]]}}"
      trimmed_sh="${sh[$i]#${sh[$i]%%[![:space:]]*}}"
      trimmed_sh="${trimmed_sh%${trimmed_sh##*[![:space:]]}}"

      rec_lit+="$trimmed_rec"
      sh_lit+="$trimmed_sh"

      # sum BPS for a friendly preview
      if [[ -n "$trimmed_sh" ]]; then
        sum_bps=$((sum_bps + trimmed_sh))
      fi
    done
    rec_lit+="]"; sh_lit+="]"

    if [[ "${PRETTY:-0}" == "1" ]]; then
      echo "Split preview (bps):"
      for i in "${!rec[@]}"; do
        tr="${rec[$i]#${rec[$i]%%[![:space:]]*}}"; tr="${tr%${tr##*[![:space:]]}}"
        ts="${sh[$i]#${sh[$i]%%[![:space:]]*}}"; ts="${ts%${ts##*[![:space:]]}}"
        echo "- $tr : $ts"
      done
      echo "Total BPS: $sum_bps (expected 10000)"

      # totally unnecessary commentary
      if [[ ${#rec[@]} -eq 2 && ( "$shares_csv" == *"5000"* && "$shares_csv" == *"5000"* ) ]]; then
        echo "50/50 = 平和。"
      elif [[ ${#rec[@]} -eq 2 && ( "$shares_csv" == *"7000"* && "$shares_csv" == *"3000"* ) ]]; then
        echo "70/30 = えらい。"
      fi
    fi

    cast_send "$ENGAGEMENT_ADDRESS" "setSplit(address[],uint256[])" "$rec_lit" "$sh_lit"
    ;;

  engagement:lock)
    require_env ENGAGEMENT_ADDRESS
    cast_send "$ENGAGEMENT_ADDRESS" "lock()"
    ;;

  engagement:set-metadata-uri)
    require_env ENGAGEMENT_ADDRESS
    uri="${1:?metadataURI}"
    cast_send "$ENGAGEMENT_ADDRESS" "setMetadataURI(string)" "$uri"
    ;;

  engagement:set-match-window)
    require_env ENGAGEMENT_ADDRESS
    startAt="${1:?startAt}"; endAt="${2:?endAt}"
    cast_send "$ENGAGEMENT_ADDRESS" "setMatchWindow(uint64,uint64)" "$startAt" "$endAt"
    ;;

  engagement:finalize)
    require_env ENGAGEMENT_ADDRESS
    cast_send "$ENGAGEMENT_ADDRESS" "finalize()"
    ;;

  engagement:cancel)
    require_env ENGAGEMENT_ADDRESS
    cast_send "$ENGAGEMENT_ADDRESS" "cancel()"
    ;;

  engagement:status)
    require_env ENGAGEMENT_ADDRESS
    echo "Engagement: $ENGAGEMENT_ADDRESS"
    print_addr_link "$ENGAGEMENT_ADDRESS"

    admin=$(cast_call "$ENGAGEMENT_ADDRESS" "admin()(address)")
    token=$(cast_call "$ENGAGEMENT_ADDRESS" "token()(address)")
    status=$(cast_call "$ENGAGEMENT_ADDRESS" "status()(uint8)")
    startAt=$(cast_call "$ENGAGEMENT_ADDRESS" "startAt()(uint64)")
    endAt=$(cast_call "$ENGAGEMENT_ADDRESS" "endAt()(uint64)")

    status_name="UNKNOWN"
    case "${status%% *}" in
      0) status_name="OPEN";;
      1) status_name="LOCKED";;
      2) status_name="CANCELLED";;
    esac

    echo "status: $status_name ($status)"
    echo "admin:  $admin"; print_addr_link "$admin"
    echo "token:  $token"; print_addr_link "$token"
    echo "startAt: $startAt"
    echo "endAt:   $endAt"
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
