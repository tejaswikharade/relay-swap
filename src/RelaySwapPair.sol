// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "./interfaces/IERC20.sol";
import {Math} from "./libraries/Math.sol";

/// @title RelaySwapPair
/// @notice A deliberately small, educational x*y=k market for exactly two ERC-20 tokens.
/// @dev It is not audited and intentionally omits a router, oracle, and production token support.
contract RelaySwapPair {
    using Math for uint256;

    error IdenticalTokens();
    error ZeroAddress();
    error ZeroAmount();
    error SlippageExceeded();
    error InsufficientLiquidity();
    error InsufficientOutput();
    error TransferFailed();
    error Reentrancy();

    string public constant name = "RelaySwap LP";
    string public constant symbol = "RLP";
    uint8 public constant decimals = 18;
    uint256 public constant MINIMUM_LIQUIDITY = 1_000;
    uint256 private constant FEE_NUMERATOR = 997;
    uint256 private constant FEE_DENOMINATOR = 1_000;

    address public immutable token0;
    address public immutable token1;
    uint112 private reserve0;
    uint112 private reserve1;
    uint256 private unlocked = 1;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Sync(uint112 reserve0, uint112 reserve1);
    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 shares);
    event LiquidityRemoved(address indexed provider, address indexed to, uint256 amount0, uint256 amount1, uint256 shares);
    event Swap(address indexed trader, address indexed to, bool token0In, uint256 amountIn, uint256 amountOut);

    modifier lock() {
        if (unlocked != 1) revert Reentrancy();
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address tokenA, address tokenB) {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (tokenA == tokenB) revert IdenticalTokens();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1) {
        return (reserve0, reserve1);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, value);
        return true;
    }

    /// @notice Supplies both tokens. Initial shares use sqrt(amount0 * amount1).
    function addLiquidity(uint256 amount0Desired, uint256 amount1Desired, uint256 minShares)
        external
        lock
        returns (uint256 shares)
    {
        if (amount0Desired == 0 || amount1Desired == 0) revert ZeroAmount();
        _safeTransferFrom(token0, msg.sender, address(this), amount0Desired);
        _safeTransferFrom(token1, msg.sender, address(this), amount1Desired);

        if (totalSupply == 0) {
            uint256 rootK = Math.sqrt(amount0Desired * amount1Desired);
            if (rootK <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
            shares = rootK - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            shares = Math.min(
                (amount0Desired * totalSupply) / reserve0,
                (amount1Desired * totalSupply) / reserve1
            );
        }
        if (shares < minShares || shares == 0) revert SlippageExceeded();
        _mint(msg.sender, shares);
        _update();
        emit LiquidityAdded(msg.sender, amount0Desired, amount1Desired, shares);
    }

    /// @notice Burns LP shares and returns the provider's pro-rata claim.
    function removeLiquidity(uint256 shares, uint256 minAmount0, uint256 minAmount1, address to)
        external
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        if (shares == 0 || to == address(0)) revert ZeroAmount();
        uint256 supply = totalSupply;
        amount0 = (shares * reserve0) / supply;
        amount1 = (shares * reserve1) / supply;
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();
        if (amount0 < minAmount0 || amount1 < minAmount1) revert SlippageExceeded();
        _burn(msg.sender, shares);
        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);
        _update();
        emit LiquidityRemoved(msg.sender, to, amount0, amount1, shares);
    }

    /// @notice Swaps one input token for the other, charging a fixed 0.30% LP fee.
    function swapExactIn(bool token0In, uint256 amountIn, uint256 minAmountOut, address to)
        external
        lock
        returns (uint256 amountOut)
    {
        if (amountIn == 0 || to == address(0)) revert ZeroAmount();
        (uint256 reserveIn, uint256 reserveOut, address input, address output) = token0In
            ? (reserve0, reserve1, token0, token1)
            : (reserve1, reserve0, token1, token0);
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);
        if (amountOut == 0 || amountOut < minAmountOut || amountOut >= reserveOut) revert InsufficientOutput();
        _safeTransferFrom(input, msg.sender, address(this), amountIn);
        _safeTransfer(output, to, amountOut);
        _update();
        emit Swap(msg.sender, to, token0In, amountIn, amountOut);
    }

    /// @notice Updates cached reserves after a direct token transfer; not a substitute for a router.
    function sync() external lock {
        _update();
    }

    function quote(uint256 amountIn, bool token0In) external view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;
        (uint256 reserveIn, uint256 reserveOut) = token0In ? (reserve0, reserve1) : (reserve1, reserve0);
        if (reserveIn == 0 || reserveOut == 0) return 0;
        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        return (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);
    }

    function _update() private {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert InsufficientLiquidity();
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }

    function _mint(address to, uint256 value) private {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) private {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function _transfer(address from, address to, uint256 value) private {
        if (to == address(0)) revert ZeroAddress();
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        if (!IERC20(token).transfer(to, value)) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) private {
        if (!IERC20(token).transferFrom(from, to, value)) revert TransferFailed();
    }
}
