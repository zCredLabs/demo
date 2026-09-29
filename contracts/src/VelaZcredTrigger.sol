// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IZcredRegistry} from "./interfaces/IZcredRegistry.sol";
import {IProcessorEndpoint} from "./interfaces/IProcessorEndpoint.sol";
import {ITokenAllowlist} from "./interfaces/ITokenAllowlist.sol";
import {VelaStructs} from "./interfaces/VelaStructs.sol";

/// @dev Minimal ERC20 interface for the token sweep in AbstractTrigger.withdraw()
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

// ══════════════════════════════════════════════════════════════════════════════
//  ITrigger — matches Horizen Vela v0.2.0 on-chain interface exactly
// ══════════════════════════════════════════════════════════════════════════════
interface ITrigger {
    event TriggerExecuted();

    error ZeroAddress();
    error NotProcessorEndpoint();

    function processorEndpoint() external view returns (IProcessorEndpoint);
    function tokenAllowlist() external view returns (ITokenAllowlist);

    function execute(VelaStructs.EventData calldata appEventData) external;

    function withdraw()
        external
        returns (
            VelaStructs.TokenAndAmount[] memory returnedTokens,
            VelaStructs.TokenAndAmount[] memory failedTokens
        );

    function getTrustProcessPayload(
        VelaStructs.EventData calldata appEventData,
        bool executeSuccess,
        bool withdrawSuccess,
        VelaStructs.TokenAndAmount[] calldata returnedTokens,
        VelaStructs.TokenAndAmount[] calldata failedTokens
    ) external returns (bytes memory trustedPayload);
}

// ══════════════════════════════════════════════════════════════════════════════
//  AbstractTrigger — mirrors Horizen Vela v0.2.0 AbstractTrigger.sol
// ══════════════════════════════════════════════════════════════════════════════
abstract contract AbstractTrigger is ITrigger {
    /// @notice ProcessorEndpoint that is allowed to call execute and withdraw.
    IProcessorEndpoint public override processorEndpoint;
    /// @notice Allowlist of ERC-20 tokens swept on withdraw.
    ITokenAllowlist public override tokenAllowlist;

    modifier _onlyProcessorEndpoint() {
        if (msg.sender != address(processorEndpoint)) {
            revert NotProcessorEndpoint();
        }
        _;
    }

    receive() external payable {}

    constructor(IProcessorEndpoint _processorEndpoint) {
        if (address(_processorEndpoint) == address(0)) revert ZeroAddress();
        processorEndpoint = _processorEndpoint;
        tokenAllowlist = _processorEndpoint.tokenAllowlist();
    }

    /// @notice Called by ProcessorEndpoint on request completion. Delegates to _execute.
    function execute(VelaStructs.EventData calldata appEventData)
        external
        override
        _onlyProcessorEndpoint
    {
        _execute(appEventData);
        emit TriggerExecuted();
    }

    /// @notice Sweeps all allowlisted ERC-20 tokens and ETH back to the ProcessorEndpoint.
    function withdraw()
        external
        override
        _onlyProcessorEndpoint
        returns (
            VelaStructs.TokenAndAmount[] memory returnedTokens,
            VelaStructs.TokenAndAmount[] memory failedTokens
        )
    {
        address[] memory tokens = tokenAllowlist.getAllowedTokens();
        uint256 length = tokens.length;

        returnedTokens = new VelaStructs.TokenAndAmount[](length + 1);
        failedTokens = new VelaStructs.TokenAndAmount[](length + 1);
        uint256 insertIntoReturned;
        uint256 insertIntoFailed;

        for (uint256 i = 0; i < length; i++) {
            address token = tokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                try IERC20(token).transfer(address(processorEndpoint), balance) {
                    returnedTokens[insertIntoReturned] = VelaStructs.TokenAndAmount({
                        token: token,
                        amount: balance
                    });
                    unchecked { ++insertIntoReturned; }
                } catch {
                    failedTokens[insertIntoFailed] = VelaStructs.TokenAndAmount({
                        token: token,
                        amount: balance
                    });
                    unchecked { ++insertIntoFailed; }
                }
            }
        }

        // Sweep ETH
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool ok,) = address(processorEndpoint).call{value: ethBalance}("");
            if (ok) {
                returnedTokens[insertIntoReturned] = VelaStructs.TokenAndAmount({
                    token: address(0),
                    amount: ethBalance
                });
                unchecked { ++insertIntoReturned; }
            } else {
                failedTokens[insertIntoFailed] = VelaStructs.TokenAndAmount({
                    token: address(0),
                    amount: ethBalance
                });
                unchecked { ++insertIntoFailed; }
            }
        }

        // Trim to actual sizes
        assembly {
            mstore(returnedTokens, insertIntoReturned)
            mstore(failedTokens, insertIntoFailed)
        }
    }

    function _execute(VelaStructs.EventData calldata appEventData) internal virtual;
}

// ══════════════════════════════════════════════════════════════════════════════
//  VelaZcredTrigger — Zcred attestation settlement trigger (Vela v0.2.0)
// ══════════════════════════════════════════════════════════════════════════════

/**
 * @title VelaZcredTrigger
 * @notice Receives packed attestation payloads emitted by the Zcred WASM guest
 *         via Horizen Vela's ProcessorEndpoint, unpacks the fields, and anchors
 *         them directly into ZcredRegistry.sol.
 *
 * @dev Conforms to Horizen Vela v0.2.0 AbstractTrigger interface with:
 *      - EventData.events[]  : packed 171-byte attestation payloads
 *      - EventData.subTypes[]: corresponding bytes32 subtypes (ignored by Zcred)
 *
 * Attestation payload layout (171 bytes):
 *   [0]      policyId    (uint8)
 *   [1..33]  nullifier   (bytes32)
 *   [33]     tierOrStatus (uint8)
 *   [34..66] customData  (bytes32)
 *   [66..74] validUntil  (uint64 big-endian)
 *   [74..139] signature  (65 bytes)
 *   [139..171] digest    (bytes32) — omitted from registry call (verified inside)
 */
contract VelaZcredTrigger is AbstractTrigger {
    // --- Constants ---
    uint256 public constant ATTESTATION_PACKED_SIZE = 171;

    // --- State ---
    IZcredRegistry public immutable registry;
    address public owner;
    bool public paused;

    // --- Events ---
    event AttestationSettled(
        uint8 indexed policyId,
        bytes32 indexed nullifier,
        uint8 tierOrStatus,
        bytes32 customData,
        uint64 validUntil
    );
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TriggerPaused(bool isPaused);

    // --- Errors ---
    error Unauthorized();
    error TriggerIsPaused();
    error NoEventsInBatch();
    error InvalidAttestationLength(uint256 expected, uint256 actual);

    // --- Modifiers ---
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert TriggerIsPaused();
        _;
    }

    constructor(
        IProcessorEndpoint _processorEndpoint,
        address _registry,
        address _owner
    ) AbstractTrigger(_processorEndpoint) {
        if (_registry == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();
        registry = IZcredRegistry(_registry);
        owner = _owner;
    }

    // --- Admin ---

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit TriggerPaused(_paused);
    }

    // --- ITrigger: getTrustProcessPayload ---

    /// @notice Zcred does not spawn trusted follow-up requests.
    function getTrustProcessPayload(
        VelaStructs.EventData calldata,
        bool,
        bool,
        VelaStructs.TokenAndAmount[] calldata,
        VelaStructs.TokenAndAmount[] calldata
    ) external pure override returns (bytes memory) {
        return "";
    }

    // --- Core Settlement ---

    /**
     * @notice Unpacks a canonical 171-byte attestation payload.
     */
    function unpackAttestation(bytes calldata payload)
        public
        pure
        returns (
            uint8 policyId,
            bytes32 nullifier,
            uint8 tierOrStatus,
            bytes32 customData,
            uint64 validUntil,
            bytes calldata signature
        )
    {
        if (payload.length != ATTESTATION_PACKED_SIZE) {
            revert InvalidAttestationLength(ATTESTATION_PACKED_SIZE, payload.length);
        }
        policyId    = uint8(payload[0]);
        nullifier   = bytes32(payload[1:33]);
        tierOrStatus = uint8(payload[33]);
        customData  = bytes32(payload[34:66]);
        validUntil  = uint64(bytes8(payload[66:74]));
        signature   = payload[74:139];
        // payload[139:171] is the EIP-712 digest (consumed by ZcredRegistry internally)
    }

    /**
     * @notice Internal hook — processes all attestation app-events and anchors them.
     *         Called by AbstractTrigger.execute() which is restricted to ProcessorEndpoint.
     */
    function _execute(VelaStructs.EventData calldata appEventData)
        internal
        override
        whenNotPaused
    {
        uint256 eventCount = appEventData.events.length;
        if (eventCount == 0) return; // TRUSTPROCESS re-entry: no events → terminate loop

        for (uint256 i = 0; i < eventCount; i++) {
            bytes calldata payload = appEventData.events[i];

            (
                uint8 policyId,
                bytes32 nullifier,
                uint8 tierOrStatus,
                bytes32 customData,
                uint64 validUntil,
                bytes calldata signature
            ) = unpackAttestation(payload);

            // Anchor into ZcredRegistry (performs cryptographic verification)
            registry.recordAttestation(
                policyId,
                nullifier,
                tierOrStatus,
                customData,
                validUntil,
                signature
            );

            emit AttestationSettled(policyId, nullifier, tierOrStatus, customData, validUntil);
        }
    }
}
