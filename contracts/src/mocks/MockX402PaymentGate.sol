// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IZcredRegistry} from "../interfaces/IZcredRegistry.sol";

/**
 * @title MockX402PaymentGate
 * @notice Production-grade gate for Autonomous AI Agent Economy & HTTP 402 Micropayments.
 * @dev Consumes Zcred Agent Passport (Policy #3) attestations with a single-slot
 *      view call to ZcredRegistry (< 26k gas). Enforces hardware-bound agent verification,
 *      developer authentication, and strict daily spending allowances without exposing keys.
 */
contract MockX402PaymentGate {
    // --- Constants ---
    uint8 public constant POLICY_ID_AGENT = 3;

    uint8 public constant STATUS_ATTESTED = 1;
    uint8 public constant STATUS_RESTRICTED = 2;
    uint8 public constant STATUS_ROGUE_OR_BLOCKED = 99;

    uint16 public constant FLAG_CODE_HASH_VERIFIED = 1 << 0;     // bit 0: 0x0001
    uint16 public constant FLAG_DEVELOPER_AUTHENTICATED = 1 << 1; // bit 1: 0x0002
    uint16 public constant FLAG_ALLOWANCE_APPROVED = 1 << 2;     // bit 2: 0x0004

    // --- Immutables ---
    IZcredRegistry public immutable registry;

    // --- State Variables ---
    mapping(bytes32 => bool) public executedRequests;

    // --- Events ---
    event MicropaymentExecuted(
        bytes32 indexed agentNullifier,
        uint64 amountUsd,
        bytes32 indexed requestId
    );
    event AgentAuthorizationVerified(
        bytes32 indexed agentNullifier,
        uint64 maxDailyAllowanceUsd,
        uint32 maxDrawdownBps
    );

    // --- Errors ---
    error ZeroAddress();
    error AgentNotAttested(uint8 status);
    error AttestationExpired(uint64 validUntil, uint256 currentTimestamp);
    error AllowanceExceeded(uint64 requestedUsd, uint64 dailyAllowanceUsd);
    error InvalidApprovalFlags(uint16 flags);
    error RequestAlreadyExecuted(bytes32 requestId);

    constructor(address _registry) {
        if (_registry == address(0)) revert ZeroAddress();
        registry = IZcredRegistry(_registry);
    }

    /**
     * @notice Authorizes and settles an autonomous HTTP 402 pay-per-query micropayment.
     * @param agentNullifier Domain-bound nullifier for the API gateway.
     * @param paymentAmountUsd Micropayment charge amount in USD.
     * @param requestId Unique identifier / invoice challenge for this query.
     */
    function verifyAndExecutePayment(
        bytes32 agentNullifier,
        uint64 paymentAmountUsd,
        bytes32 requestId
    ) external returns (bool success) {
        (bool isValid, uint8 status, bytes32 customData, uint64 validUntil) =
            registry.getAttestation(POLICY_ID_AGENT, agentNullifier);

        if (validUntil <= block.timestamp) {
            revert AttestationExpired(validUntil, block.timestamp);
        }

        if (!isValid || status != STATUS_ATTESTED) {
            revert AgentNotAttested(status);
        }

        if (executedRequests[requestId]) {
            revert RequestAlreadyExecuted(requestId);
        }

        // Unpack customData:
        // Bytes [18..26]: daily allowance USD u64 (big-endian)
        // Bytes [26..28]: flags u16 (big-endian)
        // Bytes [28..32]: max drawdown bps u32 (big-endian)
        uint64 dailyAllowanceUsd = uint64(bytes8(bytes32(customData << 144)));
        uint16 flags = uint16(bytes2(bytes32(customData << 208)));
        uint32 maxDrawdownBps = uint32(bytes4(bytes32(customData << 224)));

        // Verify required flags (Code Hash Verified + Allowance Approved)
        uint16 requiredFlags = FLAG_CODE_HASH_VERIFIED | FLAG_ALLOWANCE_APPROVED;
        if ((flags & requiredFlags) != requiredFlags) {
            revert InvalidApprovalFlags(flags);
        }

        // Enforce daily spend allowance
        if (paymentAmountUsd > dailyAllowanceUsd) {
            revert AllowanceExceeded(paymentAmountUsd, dailyAllowanceUsd);
        }

        executedRequests[requestId] = true;
        emit MicropaymentExecuted(agentNullifier, paymentAmountUsd, requestId);
        emit AgentAuthorizationVerified(agentNullifier, dailyAllowanceUsd, maxDrawdownBps);
        return true;
    }

    /**
     * @notice Performs a gas-efficient pre-flight check on an agent's authorization.
     */
    function canExecutePayment(
        bytes32 agentNullifier,
        uint64 paymentAmountUsd
    ) external view returns (bool isAuthorized, uint64 dailyAllowanceUsd, uint8 status) {
        (bool isValid, uint8 attStatus, bytes32 customData, uint64 validUntil) =
            registry.getAttestation(POLICY_ID_AGENT, agentNullifier);

        if (!isValid || attStatus != STATUS_ATTESTED || validUntil <= block.timestamp) {
            return (false, 0, attStatus);
        }

        dailyAllowanceUsd = uint64(bytes8(bytes32(customData << 144)));
        uint16 flags = uint16(bytes2(bytes32(customData << 208)));
        uint16 requiredFlags = FLAG_CODE_HASH_VERIFIED | FLAG_ALLOWANCE_APPROVED;

        if ((flags & requiredFlags) != requiredFlags || paymentAmountUsd > dailyAllowanceUsd) {
            return (false, dailyAllowanceUsd, attStatus);
        }

        return (true, dailyAllowanceUsd, attStatus);
    }
}
