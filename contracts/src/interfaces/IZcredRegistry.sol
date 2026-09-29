// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IZcredRegistry
 * @notice Interface for the Zcred Canonical Attestation Registry.
 * @dev Consuming protocols (Noct Finance, Layrs, Velum) query this interface
 *      via 1-line view calls executing in <26,000 gas.
 */
interface IZcredRegistry {
    struct AttestationRecord {
        uint8 policyId;
        uint8 tierOrStatus;
        bytes32 customData;     // Dynamic data: approved LTV, risk score hash, flags, or spending allowance
        uint64 issuedAt;
        uint64 validUntil;
        bool isRevoked;
    }

    event AttestationAnchored(
        uint8 indexed policyId,
        bytes32 indexed nullifier,
        uint8 tierOrStatus,
        bytes32 customData,
        uint64 validUntil
    );

    event AttestationRevoked(
        uint8 indexed policyId,
        bytes32 indexed nullifier
    );

    /**
     * @notice Records an attested claim verified by an authorized Horizen Vela Nitro Enclave.
     * @param policyId Unique identifier of the policy (0x01: RiskX, 0x02: Compliance, 0x03: AgentPassport).
     * @param nullifier Cryptographic domain-bound nullifier derived in-enclave.
     * @param tierOrStatus Credit tier, compliance status, or agent verification level.
     * @param customData Policy-specific payload (e.g., LTV in bps, risk hash, or allowance limit).
     * @param validUntil Unix timestamp indicating attestation expiry.
     * @param enclaveSignature ECDSA signature from the hardware enclave signer verifying the attestation digest.
     */
    function recordAttestation(
        uint8 policyId,
        bytes32 nullifier,
        uint8 tierOrStatus,
        bytes32 customData,
        uint64 validUntil,
        bytes calldata enclaveSignature
    ) external;

    /**
     * @notice Consuming view function for partner dApps (< 26,000 gas).
     * @param policyId The policy being queried.
     * @param nullifier The domain-bound nullifier for the caller's domain.
     * @return isValid True if the attestation exists, is not revoked, and is unexpired.
     * @return tierOrStatus The assigned tier or status code.
     * @return customData Dynamic policy data (e.g., approved LTV).
     * @return validUntil Expiration timestamp.
     */
    function getAttestation(uint8 policyId, bytes32 nullifier)
        external
        view
        returns (
            bool isValid,
            uint8 tierOrStatus,
            bytes32 customData,
            uint64 validUntil
        );

    /**
     * @notice Quick boolean check for valid attestation.
     */
    function isAttestationValid(uint8 policyId, bytes32 nullifier)
        external
        view
        returns (bool);
}
