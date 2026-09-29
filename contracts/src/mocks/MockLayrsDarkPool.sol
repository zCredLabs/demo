// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IZcredRegistry} from "../interfaces/IZcredRegistry.sol";

/**
 * @title MockLayrsDarkPool
 * @notice Mock implementation of the Layrs Confidential Orderbook & Dark Pool.
 * @dev Consumes Zcred Compliance Shield (Policy #2) attestations with a single-slot
 *      view call to ZcredRegistry (< 26k gas), enforcing OFAC sanctions screening
 *      and accredited investor gating without doxxing trader wallets or inspecting PII.
 */
contract MockLayrsDarkPool {
    // --- Constants ---
    uint8 public constant POLICY_ID_COMPLIANCE = 2;

    uint8 public constant STATUS_ACCREDITED = 1;
    uint8 public constant STATUS_RETAIL = 2;
    uint8 public constant STATUS_SANCTIONED = 99;

    // --- Immutables ---
    IZcredRegistry public immutable registry;

    // --- State Variables ---
    mapping(bytes32 => bool) public executedOrders;

    // --- Events ---
    event OrderPlaced(
        bytes32 indexed orderHash,
        bytes32 indexed traderNullifier,
        uint8 status
    );
    event InstitutionalOrderPlaced(
        bytes32 indexed orderHash,
        bytes32 indexed traderNullifier,
        uint32 jurisdictionMask
    );

    // --- Errors ---
    error ZeroAddress();
    error TraderSanctionedOrInvalid(uint8 status);
    error AccreditationRequired(uint8 status);
    error AttestationExpired(uint64 validUntil, uint256 currentTimestamp);
    error OrderAlreadyExecuted(bytes32 orderHash);

    constructor(address _registry) {
        if (_registry == address(0)) revert ZeroAddress();
        registry = IZcredRegistry(_registry);
    }

    /**
     * @notice Submits a standard confidential order into the retail / spot orderbook.
     * @param traderNullifier Domain-bound nullifier for layrs.xyz.
     * @param encryptedOrder Payload containing dark-pool order terms (encrypted with pool key).
     */
    function submitConfidentialOrder(
        bytes32 traderNullifier,
        bytes calldata encryptedOrder
    ) external returns (bytes32 orderHash) {
        (bool isValid, uint8 status,, uint64 validUntil) =
            registry.getAttestation(POLICY_ID_COMPLIANCE, traderNullifier);

        if (!isValid || status == 0 || status == STATUS_SANCTIONED) {
            revert TraderSanctionedOrInvalid(status);
        }

        if (validUntil <= block.timestamp) {
            revert AttestationExpired(validUntil, block.timestamp);
        }

        orderHash = keccak256(abi.encodePacked(traderNullifier, encryptedOrder, block.timestamp));
        if (executedOrders[orderHash]) {
            revert OrderAlreadyExecuted(orderHash);
        }

        executedOrders[orderHash] = true;
        emit OrderPlaced(orderHash, traderNullifier, status);
    }

    /**
     * @notice Submits an institutional order into the restricted Real World Asset (RWA) orderbook.
     *         Requires Accredited Investor status (Status = 1).
     * @param traderNullifier Domain-bound nullifier for layrs.xyz.
     * @param encryptedOrder Payload containing institutional order terms.
     */
    function submitInstitutionalRwaOrder(
        bytes32 traderNullifier,
        bytes calldata encryptedOrder
    ) external returns (bytes32 orderHash) {
        (bool isValid, uint8 status, bytes32 customData, uint64 validUntil) =
            registry.getAttestation(POLICY_ID_COMPLIANCE, traderNullifier);

        if (!isValid || status == 0 || status == STATUS_SANCTIONED) {
            revert TraderSanctionedOrInvalid(status);
        }

        if (validUntil <= block.timestamp) {
            revert AttestationExpired(validUntil, block.timestamp);
        }

        if (status != STATUS_ACCREDITED) {
            revert AccreditationRequired(status);
        }

        orderHash = keccak256(abi.encodePacked(traderNullifier, encryptedOrder, block.timestamp));
        if (executedOrders[orderHash]) {
            revert OrderAlreadyExecuted(orderHash);
        }

        executedOrders[orderHash] = true;

        // Unpack jurisdiction mask from customData bytes [22..26]
        uint32 jurisdictionMask;
        assembly {
            // customData is 32 bytes. Offset 22 bytes = shift right by (32 - 26)*8 = 48 bits, mask 32 bits
            jurisdictionMask := and(shr(48, customData), 0xFFFFFFFF)
        }

        emit InstitutionalOrderPlaced(orderHash, traderNullifier, jurisdictionMask);
    }

    /**
     * @notice Read-only check to see if a trader is eligible to trade on Layrs.
     */
    function canTrade(bytes32 traderNullifier)
        external
        view
        returns (bool canTradeSpot, bool canTradeRwa)
    {
        (bool isValid, uint8 status,, uint64 validUntil) =
            registry.getAttestation(POLICY_ID_COMPLIANCE, traderNullifier);

        if (!isValid || validUntil <= block.timestamp || status == STATUS_SANCTIONED || status == 0) {
            return (false, false);
        }

        canTradeSpot = true;
        canTradeRwa = (status == STATUS_ACCREDITED);
    }
}
