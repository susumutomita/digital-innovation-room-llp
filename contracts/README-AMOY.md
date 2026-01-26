# Polygon Amoy demo (tx-hash friendly)

This document shows how to run a full end-to-end demo on **Polygon Amoy**:

- deploy a Factory
- deploy a mock ERC20
- create an Engagement (with match window + metadataURI)
- set split, lock/finalize
- mint/approve/deposit
- distribute (one-tx push distribution)

## Network settings (official)
From Polygon Labs:
- RPC: https://rpc-amoy.polygon.technology/
- Chain ID: 80002
- Explorer: https://amoy.polygonscan.com/
- Faucet: https://faucet.polygon.technology/

Source: https://polygon.technology/blog/introducing-the-amoy-testnet-for-polygon-pos

## Prereqs
- Foundry (`forge`, `cast`)
- A funded testnet account (Amoy faucet MATIC)

## Environment
From `contracts/`:

```bash
cp .env.example .env
```

Set these:

```bash
# required
export RPC_URL=https://rpc-amoy.polygon.technology/
export PRIVATE_KEY=... # never commit

# optional but recommended
export ENGAGEMENT_ADMIN=0xYourAdminAddress
```

> Tip: derive your address from the private key:
> `cast wallet address --private-key $PRIVATE_KEY`

## 0) Build
```bash
forge build
```

## 1) Deploy EngagementFactory
```bash
./cli/engagement.sh deploy:factory
```

Copy the deployed address into:
```bash
export FACTORY_ADDRESS=0x...
```

## 2) Deploy a mock ERC20 (test payment token)
```bash
./cli/engagement.sh deploy:mock-erc20 "Mock" "MOCK" 6
```

Copy the deployed address into:
```bash
export TOKEN_ADDRESS=0x...
```

## 3) Create an Engagement
Choose a short window for demo (e.g. 2 minutes):

```bash
now=$(date +%s)
start=$now
end=$((now+120))

./cli/engagement.sh factory:create-engagement \
  $ENGAGEMENT_ADMIN \
  $TOKEN_ADDRESS \
  $start \
  $end \
  "https://example.com/metadata.json"
```

Get the Engagement address from the transaction logs (event `EngagementCreated`) on Polygonscan,
then set:

```bash
export ENGAGEMENT_ADDRESS=0x...
```

## 4) (Optional) update metadataURI / match window while OPEN
```bash
./cli/engagement.sh engagement:set-metadata-uri "https://example.com/metadata-v2.json"
./cli/engagement.sh engagement:set-match-window $start $end
```

## 5) Set split table
Example: 70/30 split

```bash
./cli/engagement.sh engagement:set-split 0xRecipient1,0xRecipient2 7000,3000
```

## 6) LOCK or finalize
### Option A: manual LOCK (admin)
```bash
./cli/engagement.sh engagement:lock
```

### Option B: permissionless finalize (after deadline)
Wait until `endAt`, then:
```bash
./cli/engagement.sh engagement:finalize
```

If split was empty => status becomes CANCELLED (NO-GO).

## 7) Mint + approve + deposit
Mint to the current signer (or to another payer, if you switch PRIVATE_KEY):

```bash
payer=$(cast wallet address --private-key $PRIVATE_KEY)

./cli/engagement.sh token:mint $payer 100000000   # 100.000000 MOCK
./cli/engagement.sh token:approve $ENGAGEMENT_ADDRESS 100000000
./cli/engagement.sh engagement:deposit 100000000
```

## 8) Distribute (one-tx push payout)
```bash
./cli/engagement.sh engagement:distribute
```

Verify balances:
```bash
cast call --rpc-url $RPC_URL $TOKEN_ADDRESS "balanceOf(address)(uint256)" 0xRecipient1
cast call --rpc-url $RPC_URL $TOKEN_ADDRESS "balanceOf(address)(uint256)" 0xRecipient2
```

---

## Notes
- For a 10-person cap, push distribution is fine.
- If you ever need to scale beyond that, add a pull/claim option.
