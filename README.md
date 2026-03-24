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
| **FailSafe** | Only admin-initiated transactions allowed. Use when you suspect compromise — locks out the bot key while retaining admin access for recovery. |

### What a compromised bot key CAN'T do

- Transfer ERC20/ERC1155 tokens (token contracts not whitelisted)
- Change Safe owners (self-calls blocked)
- Remove or change the Guard (self-calls blocked)
- Enable modules (self-calls blocked)
- Execute delegatecalls (delegatecalls blocked)
- Drain funds via gas refund parameters (gasPrice must be zero in Trading mode)
- Transact through the Safe in FailSafe mode (admin-only)

### What a compromised bot key CAN do

- Sign CLOB orders at bad prices (off-chain, Guard can't intercept)
- Cancel orders on-chain
- Bump exchange nonces

**Response to compromise:** Admin calls `switchToFailSafe()` to lock out the bot key, then removes the compromised key and revokes approvals directly in FailSafe mode. Switch back to Trading when done.

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

The test suite includes tests across unit, fork (Polygon mainnet), invariant (stateful fuzzing), and script tests.

## Deployment

### 1. Deploy the Factory

Set environment variables in `.env`:
- `OWNER_PRIVATE_KEY` — private key of the deployer
- `ETHERSCAN_API_KEY` — Polygonscan API key (for contract verification)

```bash
source .env && forge script script/DeployGuard.s.sol --rpc-url $POLYGON_RPC_URL --broadcast --verify
```

This deploys two contracts (both verified on Polygonscan):
- `GuardFactory` — anyone can call `factory.deploy(adminAddress, whitelist)` to create their own `TradingGuard`
- `TradingGuard` — a standalone instance for verification only; all factory-deployed guards inherit verification via similar-match

### 2. Deploy your Guard

Call the deployed factory to create your own `TradingGuard`:

```solidity
address guard = factory.deploy(adminAddress, whitelist);
```

- `adminAddress` — your admin key (hardware wallet recommended), becomes the guard owner who controls mode switching and whitelist
- `whitelist` — array of allowed target addresses (e.g. the three Polymarket contracts listed in [Whitelisted Polymarket Contracts](#whitelisted-polymarket-contracts-polygon))

### 3. Set the Guard on your Safe

Call `setGuard(guardAddress)` on your Safe. This is a self-call — execute it via `execTransaction` or the [Safe Transaction Builder](https://app.safe.global).

### 4. Add an admin owner to your Safe

```bash
NEW_OWNER=<admin-address> forge script script/AddOwner.s.sol --rpc-url $POLYGON_RPC_URL --broadcast
```

See the [Security](#security) section for bypass protection details.

## Contracts

| Contract | Description |
|----------|-------------|
| `TradingGuard` | Core guard — mode switching, whitelist enforcement, transaction filtering |
| `GuardFactory` | CREATE2 factory for deterministic guard deployment |
| `BaseGuard` | Abstract base with ERC-165 interface detection |
## Security

This contract has **not been audited**. Use at your own risk.

The guard blocks all known Gnosis Safe bypass vectors in Trading mode:

- **DelegateCall + MultiSend** — all delegatecalls rejected
- **Self-calls** (owner/guard/module management) — `to == msg.sender` blocked
- **Module bypass** — `enableModule` is a self-call, blocked; no modules should be enabled pre-deployment
- **Approved hash** — `approveHash` is a self-call, blocked
- **Gas refund drain** — `gasPrice != 0` rejected in Trading mode; Safe's `handlePayment` never executes

> **Note:** ETH transfers to whitelisted targets are technically allowed, but Polymarket contracts do not accept ETH.

## Support Development

If SafeWord saved your funds (or your sanity), consider supporting development:

**EVM:** `0xe87358B9e47E1C6a29cFa4E69147fdE81874ea19`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
