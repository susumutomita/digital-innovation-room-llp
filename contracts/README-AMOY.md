# Polygon Amoy demo (tx-hash friendly)

This document shows how to run an end-to-end demo on **Polygon Amoy**:

- deploy an `EngagementFactory`
- create an `Engagement` (with match window + metadataURI)
- set split, then **LOCK** (admin) *or* **finalize** (permissionless after deadline)
- approve + deposit
- distribute (one-tx push distribution)

> Note: token can be either a **real testnet JPYC** (recommended) or a **mock ERC20** for local testing.

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

Tips:
- Derive your address from the private key:
  `cast wallet address --private-key $PRIVATE_KEY`
- These scripts assume **Foundry v1.5+**.
  - Contract deploy uses `forge create --broadcast` (cast no longer has `cast create`).

---

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

Notes:
- The factory deploys an upgradeable **Beacon** internally. The beacon owner (upgrade authority) is
  initially the deployer, and should be transferred to your Safe once available.

  Transfer ownership (once your Safe exists):
  ```bash
  cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY \
    $FACTORY_ADDRESS "transferBeaconOwnership(address)" 0xYourSafeAddress
  ```

  Verify ownership:
  1. Read beacon address:
     ```bash
     cast call --rpc-url $RPC_URL $FACTORY_ADDRESS "beacon()(address)"
     ```
  2. Read beacon owner:
     ```bash
     cast call --rpc-url $RPC_URL <BEACON_ADDRESS> "owner()(address)"
     ```

## 2) Choose payment token

### Option A (recommended): JPYC on Amoy
JPYC test token faucet:
- https://faucet.jpyc.co.jp/

JPYC token contract address on **Polygon Amoy (80002)**:

```bash
export TOKEN_ADDRESS=0xE7C3D8C9a439feDe00D2600032D5dB0Be71C3c29
```

Token metadata (from faucet app config):
- symbol: `JPYC`
- decimals: `18`

Source (faucet app bundle):
- https://faucet.jpyc.co.jp/_next/static/chunks/50b66129cd80a755.js

Obtain testnet JPYC:
1. Open the faucet URL
2. Connect wallet
3. Select **Polygon Amoy**
4. Request JPYC
5. Confirm your address has JPYC on Polygonscan (Token Transfers / ERC-20 Token Txns)

### Option B: Deploy a mock ERC20 (for demo only)
```bash
./cli/engagement.sh deploy:mock-erc20 "Mock" "MOCK" 6
export TOKEN_ADDRESS=0x...
```

## 3) Create an Engagement
Choose a short window for demo (e.g. 2 minutes):

> Step-by-step tip (JPYC path): You can do the whole CLI part with the tx hashes in order:
> `deploy:factory → create-engagement → set-split → lock/finalize → approve → deposit → distribute`.
> Each command prints an Explorer link.

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

## 5) Set split table (realistic example: 3 recipients)
Example: 50/30/20 split.

```bash
./cli/engagement.sh engagement:set-split \
  0xRecipient1,0xRecipient2,0xRecipient3 \
  5000,3000,2000
```

Notes:
- Replace `0xRecipient*` with real recipient addresses.
- CSV values may include spaces (e.g. `0xA, 0xB`); the script trims leading/trailing whitespace.
- Avoid committing or publishing address lists that are meant to be private/off-chain.

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

#### Finalize demo (tx-hash example)
Below is a complete example run on Amoy (mock token) that uses **finalize** instead of `lock`.
Use it as a reference for what you should see on Polygonscan.

#### JPYC demo (tx-hash example)
To be added once JPYC test tokens are received from the faucet and the flow is executed.
(We will record tx hashes for: approve → deposit → distribute, and the EngagementCreated tx.)

- Factory: `0xF62C5Ffda4cDbe81AF1f930c0C774AE6eEa0fE5E`
- Token (MockERC20): `0xd4cEc1b06ed4AF3a90E1EdAb5c47EF00d9ffF29d`
- Engagement (created): `0xd6a35F61910b8Af3871F199B80bECbC45ecc3D94`

Transactions:
1. `factory:create-engagement` (start/end set)
   - tx: `0x27f20b7f0fcba5c49be40b00c9516ee993ce9dae433217420b1f16d9abc65fd6`
2. `engagement:set-split`
   - tx: `0x9651a12e70ca0533112125c163edc2226ec50059d452536bbc8627b2104c022c`
3. wait until `endAt` then `engagement:finalize`
   - tx: `0x7ed4328f8cc56b19ac615d9418bd58d1981cc94f6d114b211d24ddfccf290597`
4. `token:mint`
   - tx: `0xcb4b138f3814174b6087b9dd7db86032fc1d45e05d39fc981761f9a7524d7f4a`
5. `token:approve`
   - tx: `0xcb4a89ed9e6efbb8a76cea9430e4ff9c7db63ed6fffc601b8ab922ef408c97a1`
6. `engagement:deposit`
   - tx: `0x10016460c7fb453706887218c97683bcf93d492cceab6ec1d9ba58440f203044`
7. `engagement:distribute`
   - tx: `0x5028e64f976b1556fa391c6a5e088d5ff14a8416013bc8d9d788fda7dff9f770`

## 7) Approve + deposit

Payer is the current signer:

```bash
payer=$(cast wallet address --private-key $PRIVATE_KEY)
```

### If you are using mock ERC20
Mint then approve + deposit:

```bash
./cli/engagement.sh token:mint $payer 100000000   # 100.000000 (if decimals=6)
./cli/engagement.sh token:approve $ENGAGEMENT_ADDRESS 100000000
./cli/engagement.sh engagement:deposit 100000000
```

### If you are using JPYC
You cannot mint. Make sure the payer already holds JPYC, then:

#### Step A: receive JPYC test tokens
This requires a wallet UI (MetaMask).
1. Go to https://faucet.jpyc.co.jp/
2. Switch network to **Polygon Amoy**
3. Request JPYC
4. Confirm balance on Polygonscan (Token Transfers / ERC-20 Token Txns)

#### Step B: approve + deposit
```bash
# JPYC decimals=18.
# Example: 10.0 JPYC total (useful if you want to see multiple payouts clearly)
AMOUNT=10000000000000000000

./cli/engagement.sh token:approve $ENGAGEMENT_ADDRESS $AMOUNT
./cli/engagement.sh engagement:deposit $AMOUNT
```

#### Step C: distribute
```bash
./cli/engagement.sh engagement:distribute
```

Verify recipient balances (JPYC):
```bash
cast call --rpc-url $RPC_URL $TOKEN_ADDRESS "balanceOf(address)(uint256)" 0xRecipient1
cast call --rpc-url $RPC_URL $TOKEN_ADDRESS "balanceOf(address)(uint256)" 0xRecipient2
cast call --rpc-url $RPC_URL $TOKEN_ADDRESS "balanceOf(address)(uint256)" 0xRecipient3
```

## 8) Distribute (one-tx push payout)
```bash
./cli/engagement.sh engagement:distribute
```

Verify balances:
```bash
cast call --rpc-url $RPC_URL $TOKEN_ADDRESS "balanceOf(address)(uint256)" 0xRecipient1
cast call --rpc-url $RPC_URL $TOKEN_ADDRESS "balanceOf(address)(uint256)" 0xRecipient2
cast call --rpc-url $RPC_URL $TOKEN_ADDRESS "balanceOf(address)(uint256)" 0xRecipient3
```

---

## Polygonscan verification checklist (recommended)
For each step, copy the **transaction hash** and open it on:
<https://amoy.polygonscan.com/>

Confirm:
- **Status = Success**
- Expected **From/To**
- Expected **Token Transfers** (for mint/approve/deposit/distribute)
- For `factory:create-engagement`, confirm the `EngagementCreated` event and grab the new `ENGAGEMENT_ADDRESS`

## Notes
- For a 10-person cap, push distribution is fine.
- If you ever need to scale beyond that, add a pull/claim option.
