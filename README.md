# RelaySwap

An educational, two-token constant-product AMM (`x · y = k`) with a compact Solidity pair contract and a neon-terminal React demo.

## Included

- `addLiquidity`, `swapExactIn`, `removeLiquidity`, `quote`, and `sync`
- ERC-20 compatible LP shares; 0.30% fee remains in pool for LPs
- Slippage controls, reentrancy lock, checked token operations, reserve bounds, and events
- Dependency-free Foundry tests with mintable test tokens
- Responsive Vite + React landing page with an interactive quote simulator

## Run

```bash
forge test -vv
cd web && npm install && npm run dev
```

## Important

This is deliberately small and **not audited**. It supports standard ERC-20s only; do not use it for funds or production deployment without a full security review, oracle/router design, and additional token compatibility work.
