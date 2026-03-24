# Contributing to SafeWord

## Getting Started

1. Fork and clone the repository
2. Install [Foundry](https://getfoundry.sh/):
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```
3. Install dependencies:
   ```bash
   forge install
   ```
4. Set up environment:
   ```bash
   cp .env.example .env
   # Fill in POLYGON_RPC_URL with any Polygon RPC provider
   ```

## Development

### Build

```bash
forge build
```

### Run Tests

```bash
source .env && forge test -vvv
```

The test suite has 4 categories:

| Category | Files | What it tests |
|----------|-------|---------------|
| Unit | `test/TradingGuard.t.sol`, `test/GuardFactory.t.sol` | All guard logic and factory deployment in isolation using MockSafe |
| Fork | `test/TradingGuard.fork.t.sol` | Full lifecycle on a real Polygon Safe — deploy, set guard, test all modes via `execTransaction` |
| Script | `test/script/DeployGuard.t.sol`, `test/script/AddOwner.t.sol` | Deployment and owner management scripts against a Polygon fork |
| Invariant | `test/TradingGuard.invariant.t.sol` | Stateful fuzzing — random mode switches, whitelist changes, and transaction attempts to verify mode enforcement holds |

Fork and script tests require `POLYGON_RPC_URL` in `.env`.

## Pull Requests

1. Create a branch from `main`
2. Make your changes
3. Ensure all tests pass: `source .env && forge test -vvv`
4. Submit a PR with a clear description of what changed and why

### Guidelines

- Keep PRs focused — one change per PR
- All tests must pass
- Follow existing code style (see below)
- Add tests for new functionality

## Code Style

- Solidity `^0.8.20`
- Custom errors (e.g., `error TargetNotWhitelisted(address target)`) over `require` strings
- OpenZeppelin for standard patterns (`Ownable`), no other external dependencies
- No unnecessary abstractions — three similar lines of code is better than a premature helper
- No extra comments on obvious code, no docstrings on simple functions

## Reporting Issues

Use GitHub Issues. Include:

- What you expected to happen
- What actually happened
- Steps to reproduce
- Relevant environment details (Foundry version, RPC provider, network)

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
