// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";
import {SafeERC20} from
    "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/utils/SafeERC20.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ISimplifiedStaking} from "./ISimplifiedStaking.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract SimplifiedStaking is ISimplifiedStaking, ReentrancyGuard, OwnerIsCreator {
    using SafeERC20 for IERC20;

    IERC20 internal immutable i_stakingToken;
    IERC20 internal immutable i_lpToken;

    event Staked(uint256 amount, address indexed onBehalfOf);
    event Unstaked(uint256 amount, address indexed onBehalfOf);

    error CantUnstakeMoreThanStaked();

    mapping(address owner => uint256 amount) public stakes;

    constructor(address stakingTokenAddress, address lpTokenAddress) {
        i_stakingToken = IERC20(stakingTokenAddress);
        i_lpToken = IERC20(lpTokenAddress);
    }

    function stake(uint256 amount, address onBehalfOf) external override nonReentrant {
        i_stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        stakes[onBehalfOf] += amount;

        i_lpToken.safeTransfer(onBehalfOf, amount);

        emit Staked(amount, onBehalfOf);
    }

    function unstake(uint256 amount) external override nonReentrant {
        if (amount > stakes[msg.sender]) revert CantUnstakeMoreThanStaked();

        i_lpToken.safeTransferFrom(msg.sender, address(this), amount);

        stakes[msg.sender] -= amount;

        i_stakingToken.safeTransfer(msg.sender, amount);

        emit Unstaked(amount, msg.sender);
    }

    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        i_lpToken.transfer(msg.sender, amount);
    }
}
