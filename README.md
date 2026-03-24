# SafeWord

Your Polymarket Safe's safe word. A Gnosis Safe Guard that locks your bot key to trading-only — so a compromised key can sell your positions at bad prices, but can't steal your money while you grab a coffee in public.

## The Problem

Every Polymarket bot developer faces the same dilemma:

- Your bot key must stay **hot** (accessible to the bot process) to sign CLOB orders
- That same key is the **sole owner** of a Gnosis Safe holding all your trading capital
- A compromised key means **total loss** — the attacker can drain funds, modify Safe config, and sign arbitrary orders

## The Solution

Split one key into two roles using Gnosis Safe's multi-owner capability and a custom Guard:

| Role | Key | Can Do | Storage |
|------|-----|--------|---------|
| **Bot key** | Original Safe deployer EOA | Sign CLOB orders, interact with Polymarket contracts on-chain | Hot (bot process) |
| **Admin key** | Newly added Safe owner | Full Safe control: withdraw funds, manage owners, toggle Guard modes | Cold (hardware wallet) |

The `TradingGuard` contract enforces this separation. When active, only whitelisted Polymarket contract interactions go through. Everything else is blocked.

## How It Works

Three modes, controlled by the admin key:

| Mode | What happens |
|------|-------------|
| **Trading** (default) | Only calls to whitelisted Polymarket contracts allowed. Delegatecalls and self-calls are blocked. |
| **Unlocked** | All transactions allowed. Admin uses this to withdraw funds, manage owners, etc. Must manually switch back to Trading. |
| **FailSafe** | Everything blocked. The nuclear option — use when you suspect compromise and need to freeze all activity. |

### What a compromised bot key CAN'T do

- Transfer ERC20/ERC1155 tokens (token contracts not whitelisted)
- Change Safe owners (self-calls blocked)
- Remove or change the Guard (self-calls blocked)
- Enable modules (self-calls blocked)
- Execute delegatecalls (delegatecalls blocked)

### What a compromised bot key CAN do

- Sign CLOB orders at bad prices (off-chain, Guard can't intercept)
- Cancel orders on-chain
- Bump exchange nonces

**Response to compromise:** Admin calls `switchToFailSafe()` to freeze everything, then `switchToUnlocked()` to remove the compromised bot key and revoke approvals.

## Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- A Polygon RPC URL (any provider)

### Install

```bash
git clone https://github.com/<your-org>/safeword.git
cd safeword
forge install
```

### Build

```bash
forge build
```

### Test

```bash
cp .env.example .env
# Fill in POLYGON_RPC_URL in .env
source .env && forge test -vvv
```

The test suite includes 87 tests across unit, fork (Polygon mainnet), invariant (stateful fuzzing), and script tests.

## Deployment

### 1. Deploy the Guard

Set environment variables in `.env`:
- `OWNER_PRIVATE_KEY` — private key of a current Safe owner
- `ADMIN_ADDRESS` — address of the admin key (hardware wallet recommended)

```bash
source .env && forge script script/DeployGuard.s.sol --rpc-url $POLYGON_RPC_URL --broadcast
```

This deploys a `GuardFactory` and a `TradingGuard` with the three Polymarket contracts pre-whitelisted:
- CTFExchange (`0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E`)
- NegRiskCTFExchange (`0xC5d563A36AE78145C45a50134d48A1215220f80a`)
- NegRiskAdapter (`0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296`)

To also set the guard on your Safe in the same transaction, add:

```bash
SET_GUARD=true SAFE_ADDRESS=<your-safe> forge script script/DeployGuard.s.sol --rpc-url $POLYGON_RPC_URL --broadcast
```

### 2. Add an admin owner to your Safe

```bash
NEW_OWNER=<admin-address> forge script script/AddOwner.s.sol --rpc-url $POLYGON_RPC_URL --broadcast
```

See the [Security](#security) section for bypass protection details.

## Contracts

| Contract | Description | Lines |
|----------|-------------|-------|
| `TradingGuard` | Core guard — mode switching, whitelist enforcement, transaction filtering | 90 |
| `GuardFactory` | CREATE2 factory for deterministic guard deployment | 42 |
| `BaseGuard` | Abstract base with ERC-165 interface detection | 12 |

### Whitelisted Polymarket Contracts (Polygon)

| Contract | Address | Why Safe |
|----------|---------|----------|
| CTFExchange | `0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E` | `cancelOrder`, `incrementNonce` — no fund movement |
| NegRiskCTFExchange | `0xC5d563A36AE78145C45a50134d48A1215220f80a` | Same as CTFExchange |
| NegRiskAdapter | `0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296` | `convertPositions`, `splitPosition`, `mergePositions`, `redeemPositions` — funds cycle back to Safe |

## Security

This contract has **not been audited**. Use at your own risk.

The guard blocks all known Gnosis Safe bypass vectors in Trading mode:

- **DelegateCall + MultiSend** — all delegatecalls rejected
- **Self-calls** (owner/guard/module management) — `to == msg.sender` blocked
- **Module bypass** — `enableModule` is a self-call, blocked; no modules should be enabled pre-deployment
- **Approved hash** — `approveHash` is a self-call, blocked

> **Note:** ETH transfers to whitelisted targets are technically allowed, but Polymarket contracts do not accept ETH.

## Support Development

If SafeWord saved your funds (or your sanity), consider supporting development:

**EVM:** `0xe87358B9e47E1C6a29cFa4E69147fdE81874ea19`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
