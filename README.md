# digital-innovation-room-llp

Prototype smart contracts + minimal docs for a **per-engagement (project-by-project) revenue split** model.

Core idea:
- The legal/contracting “container” can be an LLP (off-chain).
- On-chain, each engagement has its own **split table** (participants + shares), which can be locked, and then used to automatically distribute incoming payments.

## Repo layout
- `contracts/` Foundry (Solidity)
- `docs/` product docs (PR/FAQ)

## Quick start (contracts)
```bash
cd contracts
forge test
```

## Testnet deployment (Polygon Amoy)
See `contracts/script/Deploy.s.sol` and `contracts/.env.example`.

> Note: this repo is a prototype. Do legal/tax review for real operations.
