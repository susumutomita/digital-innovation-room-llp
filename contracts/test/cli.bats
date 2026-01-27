#!/usr/bin/env bats

setup() {
  export TMPBIN="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "$TMPBIN"
  export PATH="$TMPBIN:$PATH"
  export RPC_URL="http://example-rpc"
  export PRIVATE_KEY="0xdeadbeef"
  export ENGAGEMENT_ADDRESS="0x1111111111111111111111111111111111111111"

  # fake cast
  cat > "$TMPBIN/cast" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cmd="$1"; shift || true
case "$cmd" in
  send)
    # minimal receipt-like output
    echo "status               1 (success)"
    echo "transactionHash      0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    ;;
  call)
    to="$1"; sig="$2"; shift 2
    case "$sig" in
      "admin()(address)") echo "0x2222222222222222222222222222222222222222";;
      "token()(address)") echo "0x3333333333333333333333333333333333333333";;
      "status()(uint8)") echo "1";;
      "startAt()(uint64)") echo "100";;
      "endAt()(uint64)") echo "200";;
      *) echo "0";;
    esac
    ;;
  *)
    echo "unsupported cast cmd" >&2
    exit 1
    ;;
esac
SH
  chmod +x "$TMPBIN/cast"

  # fake forge (only needed if someone calls deploy commands in tests)
  cat > "$TMPBIN/forge" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "create" ]]; then
  echo "Deployed to: 0x4444444444444444444444444444444444444444"
  echo "Transaction hash: 0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  exit 0
fi
if [[ "$1" == "--version" ]]; then
  echo "forge 1.5.1"
  exit 0
fi
# noop
exit 0
SH
  chmod +x "$TMPBIN/forge"
}

@test "engagement:status prints mapped status and links" {
  run bash -lc "cd contracts && ./cli/engagement.sh engagement:status"
  [ "$status" -eq 0 ]
  [[ "$output" == *"status: LOCKED"* ]]
  [[ "$output" == *"Explorer:"*"/address/0x1111111111111111111111111111111111111111"* ]]
}

@test "engagement:set-split PRETTY=1 trims whitespace and prints Total BPS" {
  run bash -lc "cd contracts && PRETTY=1 ./cli/engagement.sh engagement:set-split '0xA, 0xB' '5000, 5000'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total BPS: 10000"* ]]
  [[ "$output" == *"50/50"* ]]
}

@test "cast_send prints tx explorer link" {
  run bash -lc "cd contracts && ./cli/engagement.sh engagement:lock"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Explorer:"*"/tx/0xaaaaaaaa"* ]]
}
