// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IZcredRegistry} from "../interfaces/IZcredRegistry.sol";

/**
 * @title MockNoctLendingPool
 * @notice Reference partner implementation demonstrating Noct Finance's integration with Zcred RiskX.
 * @dev Replaces static 140% overcollateralization with dynamic risk-adjusted collateral tiers (<26k gas).
 */
contract MockNoctLendingPool {
    IZcredRegistry public immutable ZCRED_REGISTRY;
    uint8 public constant POLICY_ID_RISKX = 1;

    // Collateral ratios in basis points (10000 = 100%)
    uint256 public constant RATIO_TIER_AAA = 10500; // 105% (95.2% LTV)
    uint256 public constant RATIO_TIER_AA  = 11500; // 115% (86.9% LTV)
    uint256 public constant RATIO_TIER_A   = 12500; // 125% (80.0% LTV)
    uint256 public constant RATIO_TIER_BBB = 13500; // 135% (74.0% LTV)
    uint256 public constant RATIO_DEFAULT  = 14000; // 140% (Standard Overcollateralized)

    // User borrow state
    mapping(address => uint256) public userCollateral;
    mapping(address => uint256) public userBorrowed;

    event CollateralDeposited(address indexed user, uint256 amount);
    event LoanDrawn(address indexed user, uint256 amount, uint8 creditTier, uint256 appliedRatioBps);

    error InsufficientCollateral();
    error ZeroAmount();

    constructor(address _zcredRegistry) {
        ZCRED_REGISTRY = IZcredRegistry(_zcredRegistry);
    }

    function depositCollateral() external payable {
        if (msg.value == 0) revert ZeroAmount();
        userCollateral[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    /**
     * @notice Computes maximum borrow amount and effective collateral ratio using 1-line Zcred view call.
     * @param userNullifier Domain-bound nullifier for Noct Finance.
     */
    function getBorrowingTerms(address user, bytes32 userNullifier)
        public
        view
        returns (
            uint256 maxBorrowAmount,
            uint8 creditTier,
            uint256 requiredCollateralBps
        )
    {
        uint256 collateral = userCollateral[user];

        // 1-Line View Call to ZcredRegistry (< 26,000 gas)
        (bool isValid, uint8 tier,, uint64 validUntil) = 
            ZCRED_REGISTRY.getAttestation(POLICY_ID_RISKX, userNullifier);

        if (isValid && block.timestamp <= validUntil) {
            creditTier = tier;
            if (tier == 1) {
                requiredCollateralBps = RATIO_TIER_AAA; // 105%
            } else if (tier == 2) {
                requiredCollateralBps = RATIO_TIER_AA;  // 115%
            } else if (tier == 3) {
                requiredCollateralBps = RATIO_TIER_A;   // 125%
            } else if (tier == 4) {
                requiredCollateralBps = RATIO_TIER_BBB; // 135%
            } else {
                requiredCollateralBps = RATIO_DEFAULT;  // 140%
            }
        } else {
            creditTier = 0;
            requiredCollateralBps = RATIO_DEFAULT;      // 140%
        }

        // maxBorrow = (collateral * 10000) / requiredRatioBps
        maxBorrowAmount = (collateral * 10000) / requiredCollateralBps;
    }

    /**
     * @notice Simulates drawing an undercollateralized loan with verified credit tier.
     */
    function borrow(bytes32 userNullifier, uint256 amount) external {
        (uint256 maxBorrow, uint8 tier, uint256 ratioBps) = getBorrowingTerms(msg.sender, userNullifier);

        if (userBorrowed[msg.sender] + amount > maxBorrow) {
            revert InsufficientCollateral();
        }

        userBorrowed[msg.sender] += amount;
        emit LoanDrawn(msg.sender, amount, tier, ratioBps);
    }
}
