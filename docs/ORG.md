# Digital Innovation Room LLP — Operating System (LLP DAO)

This document defines how we operate as an **LLP DAO** with **OpenClaw as the manager**.

Goal: when you wake up, you feel: **“it moved a lot while I slept.”**

## 0) Core principle

- We do **not** manage people.
- We manage **permissions, safety boundaries, and throughput**.
- Day-to-day execution is delegated to **OpenClaw**.
- High-impact actions require **explicit human signatures** (Safe).

## 1) What is fixed vs. what is flexible

### Fixed (hard boundaries)
These are the “company skeleton” and must remain stable:

1. **Treasury safety**
   - Funds cannot move without Safe approval.
2. **Upgrade authority safety**
   - Upgrade authority is owned by Safe.
3. **Membership / role assignment safety**
   - Adding/removing privileged roles is gated by Safe.
4. **Auditability**
   - Every material decision is traceable to a PR, tx hash, or signed message.

### Flexible (fast iteration)
These can change frequently:

- Priority, roadmap, experiments
- Implementation details
- Internal processes and templates
- Tooling and automation (CI, bots, agents)

## 2) Roles and permissions

We separate *execution* from *authority*.

### Owner (Safe)
**What it is:** the final authority boundary.

**Can:**
- approve treasury transfers
- transfer/accept upgrade ownership (beacon/proxy/admin)
- grant/revoke privileged roles
- approve emergency actions (pause/stop)

**Cannot (by policy):**
- do daily management; this is delegated

### OpenClaw (Manager)
**What it is:** the execution manager.

**Can (default):**
- create PRs, update docs, run tests, refactor
- propose tx data for Safe to execute
- run simulations / dry-runs
- maintain CI and developer tooling

**Cannot (by boundary):**
- move treasury funds
- execute upgrades on mainnet
- change privileged membership/roles

### Guardian
**What it is:** emergency safety role.

**Can:**
- trigger emergency stops (pause / freeze) **if and only if** the contracts support it
- request Safe to take immediate action

### Auditor
**What it is:** verification role.

**Can:**
- review PRs + test reports
- independently reproduce builds/tests
- sanity-check tx data before Safe execution

### Contributors
**Can:**
- open PRs
- propose changes

**Cannot:**
- merge without approvals (repo policy)
- any privileged onchain actions

## 3) Operating cadence

### Daily (OpenClaw)
- Maintain a single “active objective” per day.
- Always leave at least one **reviewable artifact**:
  - PR with tests passing
  - a doc update with step-by-step instructions
  - a reproducible script

### Weekly (Owner/Safe)
- Approve only the minimum necessary:
  - upgrades
  - treasury actions
  - role updates

## 4) Default workflow (PR-driven)

1. OpenClaw creates PR
2. CI must be green
3. Review happens in-thread (context separated)
4. Merge happens after approval
5. Any onchain action is recorded by:
   - tx hash + network
   - link to explorer
   - copy/paste of calldata where relevant

## 5) Upgrade policy (because upgrades are rare)

We assume upgrades are **possible** but **rare**.

Minimum requirements for upgrades:
- an upgrade test exists (V1 → V2 storage compatibility)
- fuzz/invariant tests pass
- a rollback plan exists
- Safe signs the upgrade

## 6) Emergency playbook

### If funds are at risk
1. Stop all outgoing transfers (Safe policy)
2. Disable/avoid any upgrade attempts
3. Rotate keys if compromise is suspected
4. Post-mortem doc + follow-up PR

### If upgrade path is at risk
1. Freeze upgrades (Safe refuses)
2. Investigate with reproduction steps
3. Patch via PR

## 7) Metrics (simple, measurable)

We optimize for throughput *with safety*.

- PR throughput: merged PRs/day
- Lead time: time from idea → merged PR
- Reliability: CI pass rate
- Safety: number of incidents (aim: 0)

---

## Appendix: Contract ownership checklist

When Safe is created:
- transfer upgrade authority to Safe
- verify owner on chain
- record tx hash in docs
