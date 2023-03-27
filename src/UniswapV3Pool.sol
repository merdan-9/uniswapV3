// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.14;

import {Tick} from "./lib/Tick.sol";
import {Position} from "./lib/Position.sol";

import {IERC20} from "./interfaces/IERC20.sol";
import {IUniswapV3MintCallback} from "./interfaces/IUniswapV3MintCallback.sol";


import "forge-std/console.sol";

contract UniswapV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    error Error_InvalidTickRange();
    error Error_ZeroLiquidity();
    error Error_InsufficientInputAmount();

    event Mint(
        address sender,
        address indexed owner,
        int24 indexed lowerTick,
        int24 indexed upperTick,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = 887272;

    address public immutable token0;
    address public immutable token1;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
    }

    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    Slot0 public slot0;

    uint128 public liquidity;

    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    constructor(
        address token0_,
        address token1_,
        uint160 sqrtPriceX96,
        int24 tick
    ) {
        token0 = token0_;
        token1 = token1_;

        slot0 = Slot0({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick
        });
    }

    function mint(address owner, int24 lowerTick, int24 upperTick, uint128 amount, bytes calldata data)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        if (
            lowerTick >= upperTick ||
            lowerTick < MIN_TICK ||
            upperTick > MAX_TICK
        ) revert Error_InvalidTickRange();

        if (amount == 0) revert Error_ZeroLiquidity();

        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);

        Position.Info storage position = positions.get(
            owner,
            lowerTick,
            upperTick
        );
        position.update(amount);
        


        amount0 = 0.998976618347425280 ether;
        amount1 = 5000 ether;

        liquidity += uint128(amount);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(
            amount0, 
            amount1,
            data
        );

        if (amount0 > 0 && balance0Before  + amount0 > balance0())
            revert Error_InsufficientInputAmount();
        if (amount1 > 0 && balance1Before  + amount1 > balance1())
            revert Error_InsufficientInputAmount();
        
        emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);

    }

    function balance0() internal returns (uint256 balance) {
        return IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns (uint256 balance) {
        return IERC20(token1).balanceOf(address(this));
    }
}