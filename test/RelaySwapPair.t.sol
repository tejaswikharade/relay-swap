// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RelaySwapPair} from "../src/RelaySwapPair.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @notice Dependency-free Foundry tests: run `forge test -vv`.
contract RelaySwapPairTest {
    RelaySwapPair private pair;
    MockERC20 private alpha;
    MockERC20 private beta;
    uint256 private constant UNIT = 1e18;

    function setUp() public {
        alpha = new MockERC20("Alpha", "ALPHA");
        beta = new MockERC20("Beta", "BETA");
        pair = new RelaySwapPair(address(alpha), address(beta));

        alpha.mint(address(this), 10_000 * UNIT);
        beta.mint(address(this), 10_000 * UNIT);
        alpha.approve(address(pair), type(uint256).max);
        beta.approve(address(pair), type(uint256).max);
    }

    function testInitialLiquidityMintsSharesAndStoresReserves() public {
        uint256 shares = pair.addLiquidity(1_000 * UNIT, 1_000 * UNIT, 1);
        (uint112 reserve0, uint112 reserve1) = pair.getReserves();
        require(shares == 1_000 * UNIT - pair.MINIMUM_LIQUIDITY(), "unexpected LP shares");
        require(reserve0 == 1_000 * UNIT && reserve1 == 1_000 * UNIT, "reserves not synced");
    }

    function testSwapChargesFeeAndIncreasesInvariant() public {
        pair.addLiquidity(1_000 * UNIT, 1_000 * UNIT, 1);
        (uint112 before0, uint112 before1) = pair.getReserves();
        uint256 output = pair.swapExactIn(true, 100 * UNIT, 1, address(this));
        (uint112 after0, uint112 after1) = pair.getReserves();
        require(output > 90 * UNIT && output < 91 * UNIT, "unexpected output");
        require(uint256(after0) * uint256(after1) > uint256(before0) * uint256(before1), "k should grow from fee");
    }

    function testRemoveLiquidityReturnsUnderlying() public {
        uint256 shares = pair.addLiquidity(1_000 * UNIT, 1_000 * UNIT, 1);
        uint256 alphaBefore = alpha.balanceOf(address(this));
        uint256 betaBefore = beta.balanceOf(address(this));
        pair.removeLiquidity(shares / 2, 1, 1, address(this));
        require(alpha.balanceOf(address(this)) > alphaBefore, "alpha not returned");
        require(beta.balanceOf(address(this)) > betaBefore, "beta not returned");
    }

    function testSwapRevertsWithoutLiquidity() public {
        (bool ok,) = address(pair).call(
            abi.encodeCall(pair.swapExactIn, (true, UNIT, 0, address(this)))
        );
        require(!ok, "empty-pool swap should fail");
    }
}
