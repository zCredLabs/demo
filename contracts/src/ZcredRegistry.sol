// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IZcredRegistry} from "./interfaces/IZcredRegistry.sol";
import {ITeeAuthenticator} from "./interfaces/ITeeAuthenticator.sol";

/**
 * @title ZcredRegistry
 * @notice The canonical on-chain settlement registry for Zcred Confidential Decisions.
 * @dev Anchors domain-bound attestations generated inside Horizen Vela AWS Nitro Enclaves.
 *      Enforces EIP-712 domain separation (chainId + contract binding) and provides
 *      ultra-low-gas (< 26k gas) single-line view calls for consuming DeFi protocols.
 */
contract ZcredRegistry is IZcredRegistry {
    // --- Constant Typehashes (EIP-712) ---
    bytes32 public constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 public constant ATTESTATION_TYPEHASH = keccak256(
        "Attestation(uint8 policyId,bytes32 nullifier,uint8 tierOrStatus,bytes32 customData,uint64 validUntil)"
    );

    bytes32 public immutable HASHED_NAME;
    bytes32 public immutable HASHED_VERSION;
    uint256 public immutable INITIAL_CHAIN_ID;
    bytes32 public immutable INITIAL_DOMAIN_SEPARATOR;

    // --- State Variables ---
    ITeeAuthenticator public teeAuthenticator;
    address public owner;
    bool public paused;

    // Mapping: keccak256(abi.encodePacked(policyId, nullifier)) => AttestationRecord
    mapping(bytes32 => AttestationRecord) public attestations;

    // --- Events ---
    event AuthenticatorUpdated(address indexed previousAuth, address indexed newAuth);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RegistryPaused(bool isPaused);

    // --- Errors ---
    error Unauthorized();
    error RegistryIsPaused();
    error AttestationAlreadyExpired();
    error InvalidTeeSignature();
    error ZeroAddress();

    // --- Modifiers ---
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    modifier whenNotPaused() {
        _checkNotPaused();
        _;
    }

    function _checkOwner() internal view {
        if (msg.sender != owner) revert Unauthorized();
    }

    function _checkNotPaused() internal view {
        if (paused) revert RegistryIsPaused();
    }

    constructor(address _teeAuthenticator) {
        if (_teeAuthenticator == address(0)) revert ZeroAddress();

        owner = msg.sender;
        teeAuthenticator = ITeeAuthenticator(_teeAuthenticator);

        bytes32 nameHash = keccak256(bytes("ZcredRegistry"));
        bytes32 versionHash = keccak256(bytes("1"));

        HASHED_NAME = nameHash;
        HASHED_VERSION = versionHash;
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _buildDomainSeparator(nameHash, versionHash, block.chainid);
    }

    // --- External Functions ---

    /**
     * @inheritdoc IZcredRegistry
     */
    function recordAttestation(
        uint8 policyId,
        bytes32 nullifier,
        uint8 tierOrStatus,
        bytes32 customData,
        uint64 validUntil,
        bytes calldata enclaveSignature
    ) external override whenNotPaused {
        if (validUntil <= block.timestamp) {
            revert AttestationAlreadyExpired();
        }

        // Compute EIP-712 typed data digest
        bytes32 digest = computeDigest(
            policyId,
            nullifier,
            tierOrStatus,
            customData,
            validUntil
        );

        // Verify enclave signature via Horizen Vela ITeeAuthenticator
        if (!teeAuthenticator.verifyEnclaveSignature(digest, enclaveSignature)) {
            revert InvalidTeeSignature();
        }

        bytes32 recordKey = computeRecordKey(policyId, nullifier);

        // Storage slot 0: policyId (1), tierOrStatus (1), isRevoked (1), issuedAt (8), validUntil (8)
        // Storage slot 1: customData (32)
        attestations[recordKey] = AttestationRecord({
            policyId: policyId,
            tierOrStatus: tierOrStatus,
            customData: customData,
            issuedAt: uint64(block.timestamp),
            validUntil: validUntil,
            isRevoked: false
        });

        emit AttestationAnchored(policyId, nullifier, tierOrStatus, customData, validUntil);
    }

    /**
     * @notice Emergency revocation of an attestation by registry owner.
     */
    function revokeAttestation(uint8 policyId, bytes32 nullifier) external onlyOwner {
        bytes32 recordKey = computeRecordKey(policyId, nullifier);
        attestations[recordKey].isRevoked = true;

        emit AttestationRevoked(policyId, nullifier);
    }

    // --- View Functions (< 26,000 gas) ---

    /**
     * @inheritdoc IZcredRegistry
     */
    function getAttestation(uint8 policyId, bytes32 nullifier)
        external
        view
        override
        returns (
            bool isValid,
            uint8 tierOrStatus,
            bytes32 customData,
            uint64 validUntil
        )
    {
        bytes32 recordKey = computeRecordKey(policyId, nullifier);
        AttestationRecord memory record = attestations[recordKey];

        isValid = (record.issuedAt > 0) &&
                  (!record.isRevoked) &&
                  (block.timestamp <= record.validUntil);

        return (isValid, record.tierOrStatus, record.customData, record.validUntil);
    }

    /**
     * @inheritdoc IZcredRegistry
     */
    function isAttestationValid(uint8 policyId, bytes32 nullifier)
        external
        view
        override
        returns (bool)
    {
        bytes32 recordKey = computeRecordKey(policyId, nullifier);
        AttestationRecord memory record = attestations[recordKey];

        return (record.issuedAt > 0) &&
               (!record.isRevoked) &&
               (block.timestamp <= record.validUntil);
    }

    /**
     * @notice Returns the full raw attestation record struct.
     */
    function getAttestationRecord(uint8 policyId, bytes32 nullifier)
        external
        view
        returns (AttestationRecord memory)
    {
        return attestations[computeRecordKey(policyId, nullifier)];
    }

    /**
     * @notice Derives the storage mapping key for a given policy and nullifier.
     */
    function computeRecordKey(uint8 policyId, bytes32 nullifier)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(policyId, nullifier));
    }

    /**
     * @notice Computes the exact EIP-712 digest that the Horizen Vela enclave must sign.
     */
    function computeDigest(
        uint8 policyId,
        bytes32 nullifier,
        uint8 tierOrStatus,
        bytes32 customData,
        uint64 validUntil
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                ATTESTATION_TYPEHASH,
                policyId,
                nullifier,
                tierOrStatus,
                customData,
                validUntil
            )
        );

        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                getDomainSeparator(),
                structHash
            )
        );
    }

    /**
     * @notice Returns the active EIP-712 domain separator (handles hardfork chainId changes).
     */
    function getDomainSeparator() public view returns (bytes32) {
        if (block.chainid == INITIAL_CHAIN_ID) {
            return INITIAL_DOMAIN_SEPARATOR;
        }
        return _buildDomainSeparator(HASHED_NAME, HASHED_VERSION, block.chainid);
    }

    // --- Admin Functions ---

    function setTeeAuthenticator(address _newAuth) external onlyOwner {
        if (_newAuth == address(0)) revert ZeroAddress();
        emit AuthenticatorUpdated(address(teeAuthenticator), _newAuth);
        teeAuthenticator = ITeeAuthenticator(_newAuth);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit RegistryPaused(_paused);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    // --- Internal Helpers ---

    function _buildDomainSeparator(
        bytes32 nameHash,
        bytes32 versionHash,
        uint256 chainId
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                nameHash,
                versionHash,
                chainId,
                address(this)
            )
        );
    }
}
