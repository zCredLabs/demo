// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ITeeAuthenticator} from "./interfaces/ITeeAuthenticator.sol";
import {CborDecoder} from "./libraries/CborDecoder.sol";
import {X509Verifier} from "./libraries/X509Verifier.sol";

/**
 * @title TeeAuthenticator
 * @notice Production AWS Nitro Enclave Attestation & Hardware Verification Gateway for Horizen Vela.
 * @dev Supports dual-mode operation:
 *      - Production (`useHardwareAttestation == true`): Enforces RFC 9052 COSE_Sign1 parsing,
 *        RFC 8949 CBOR decoding, PCR0/1/2 measurement checks, X.509 certificate chain validation,
 *        and freshness/replay defense via challenge nonces.
 *      - Dev / Testnet Mock (`useHardwareAttestation == false`): Allows governance-authorized test signers.
 */
contract TeeAuthenticator is ITeeAuthenticator {
    // --- Constants ---
    uint256 public constant MAX_ATTESTATION_AGE_SECONDS = 3600; // 1 hour max age
    uint256 public constant DEFAULT_ENCLAVE_LEASE_PERIOD = 30 days;

    // --- State Variables ---
    address public owner;
    bool public immutable useHardwareAttestation;

    // Active primary enclave signer
    address public enclaveSigner;

    // Governance-approved PCR0 code measurements (SHA-256 of the authentic zcred_kernel.wasm binary)
    mapping(bytes32 => bool) public allowedPcr0s;

    // Replay protection: tracking spent nonces
    mapping(bytes32 => bool) public usedNonces;

    // Registered attested enclaves
    struct EnclaveRecord {
        bool isAuthorized;
        uint256 registeredAt;
        uint256 expiresAt;
        bytes32 pcr0;
    }
    mapping(address => EnclaveRecord) public registeredEnclaves;

    // Dev mode fallback authorized signers
    mapping(address => bool) public authorizedSigners;

    // Emergency circuit breaker
    bool public paused;

    // --- Events ---
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EnclaveRegistered(
        address indexed enclaveSigner,
        bytes32 indexed pcr0,
        uint64 quoteTimestampMs,
        uint256 expiresAt
    );
    event EnclaveRevoked(address indexed enclaveSigner, string reason);
    event AllowedPcr0Updated(bytes32 indexed pcr0, bool allowed);
    event NonceConsumed(bytes32 indexed nonce);
    event EnclaveSignerUpdated(address indexed previousSigner, address indexed newSigner);
    event PausedStateChanged(bool isPaused);

    // --- Errors ---
    error Unauthorized();
    error ContractPaused();
    error HardwareAttestationDisabled();
    error NonceAlreadyUsed(bytes32 nonce);
    error NonceMismatch(bytes32 expected, bytes actual);
    error AttestationTimestampInFuture(uint64 quoteTimestampMs, uint256 currentMs);
    error AttestationExpired(uint64 quoteTimestampMs, uint256 currentMs);
    error UntrustedPcr0(bytes32 pcr0);
    error InvalidUserDataLength(uint256 length);
    error InvalidSignerAddress();
    error CertificateChainInvalid();
    error EnclaveNotAuthorizedOrExpired(address signer);
    error InvalidSignatureLength();
    error InvalidSignatureV();
    error SignatureMalleability();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    /**
     * @notice Initializes the TeeAuthenticator.
     * @param _owner Governance owner address.
     * @param _useHardwareAttestation True for strict production hardware verification, false for dev mode.
     * @param _initialSigner Optional initial signer (used in dev mode or as bootstrap anchor).
     */
    constructor(
        address _owner,
        bool _useHardwareAttestation,
        address _initialSigner
    ) {
        owner = _owner == address(0) ? msg.sender : _owner;
        useHardwareAttestation = _useHardwareAttestation;

        if (_initialSigner != address(0)) {
            enclaveSigner = _initialSigner;
            authorizedSigners[_initialSigner] = true;
            registeredEnclaves[_initialSigner] = EnclaveRecord({
                isAuthorized: true,
                registeredAt: block.timestamp,
                expiresAt: block.timestamp + DEFAULT_ENCLAVE_LEASE_PERIOD,
                pcr0: bytes32(0)
            });
        }
    }

    // --- Governance Configuration ---

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidSignerAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setAllowedPcr0(bytes32 pcr0, bool allowed) external onlyOwner {
        allowedPcr0s[pcr0] = allowed;
        emit AllowedPcr0Updated(pcr0, allowed);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    function revokeEnclave(address _enclaveSigner, string calldata reason) external onlyOwner {
        registeredEnclaves[_enclaveSigner].isAuthorized = false;
        authorizedSigners[_enclaveSigner] = false;
        emit EnclaveRevoked(_enclaveSigner, reason);
    }

    // --- Dev Mode Administration (Only active when useHardwareAttestation == false) ---

    function setEnclaveSigner(address _signer) external onlyOwner {
        if (useHardwareAttestation) revert HardwareAttestationDisabled();
        emit EnclaveSignerUpdated(enclaveSigner, _signer);
        authorizedSigners[enclaveSigner] = false;
        enclaveSigner = _signer;
        authorizedSigners[_signer] = true;
    }

    function setSignerAuthorized(address _signer, bool _authorized) external onlyOwner {
        if (useHardwareAttestation) revert HardwareAttestationDisabled();
        authorizedSigners[_signer] = _authorized;
    }

    // --- Production Hardware Attestation Registration ---

    /**
     * @notice Registers a new ephemeral enclave signer by verifying an AWS Nitro COSE_Sign1 quote.
     * @param coseDocument The raw binary CBOR-encoded COSE_Sign1 attestation document from /dev/nsm.
     * @param challengeNonce The 32-byte cryptographic challenge nonce requested prior to enclave call.
     * @return registeredSigner The authenticated ephemeral secp256k1 Ethereum address.
     */
    function registerEnclaveWithAttestation(
        bytes calldata coseDocument,
        bytes32 challengeNonce
    ) external whenNotPaused returns (address registeredSigner) {
        // 1. Replay defense check
        if (usedNonces[challengeNonce]) {
            revert NonceAlreadyUsed(challengeNonce);
        }
        usedNonces[challengeNonce] = true;
        emit NonceConsumed(challengeNonce);

        // 2. Decode CBOR / COSE_Sign1 document
        CborDecoder.NitroAttestation memory att = CborDecoder.parseNitroDocument(coseDocument);

        // 3. Verify Nonce matches challenge
        if (att.nonce.length == 32) {
            bytes32 docNonce;
            bytes memory n = att.nonce;
            assembly {
                docNonce := mload(add(n, 32))
            }
            if (docNonce != challengeNonce) {
                revert NonceMismatch(challengeNonce, att.nonce);
            }
        } else {
            if (keccak256(att.nonce) != keccak256(abi.encodePacked(challengeNonce))) {
                revert NonceMismatch(challengeNonce, att.nonce);
            }
        }

        // 4. Verify Freshness: Timestamp must be within MAX_ATTESTATION_AGE_SECONDS
        uint256 currentMs = block.timestamp * 1000;
        if (att.timestamp > currentMs + 60_000) {
            // Allow 60s clock drift
            revert AttestationTimestampInFuture(att.timestamp, currentMs);
        }
        if (currentMs > att.timestamp && (currentMs - att.timestamp) > MAX_ATTESTATION_AGE_SECONDS * 1000) {
            revert AttestationExpired(att.timestamp, currentMs);
        }

        // 5. Verify PCR0 measurement (authentic zcred_kernel.wasm code hash)
        bytes32 pcr0Measurement;
        if (att.pcr0.length == 32) {
            bytes memory p0 = att.pcr0;
            assembly {
                pcr0Measurement := mload(add(p0, 32))
            }
        } else if (att.pcr0.length == 48) {
            // SHA-384 PCR0: take sha256 of the 48-byte measurement for 32-byte keying
            pcr0Measurement = sha256(att.pcr0);
        } else {
            pcr0Measurement = sha256(att.pcr0);
        }

        if (!allowedPcr0s[pcr0Measurement]) {
            revert UntrustedPcr0(pcr0Measurement);
        }

        // 6. Verify X.509 Certificate Chain of Trust
        bool certValid = X509Verifier.verifyCertificateChain(
            att.certificate,
            att.caBundle,
            block.timestamp
        );
        if (!certValid) {
            revert CertificateChainInvalid();
        }

        // 7. Extract ephemeral Ethereum signer address from user_data
        if (att.userData.length != 20) {
            revert InvalidUserDataLength(att.userData.length);
        }

        bytes memory ud = att.userData;
        address signer;
        assembly {
            // Load 32 bytes starting at userData data offset, shift right by 96 bits (12 bytes)
            signer := shr(96, mload(add(ud, 32)))
        }

        if (signer == address(0)) {
            revert InvalidSignerAddress();
        }

        // 8. Register Enclave
        uint256 leaseExpiration = block.timestamp + DEFAULT_ENCLAVE_LEASE_PERIOD;
        registeredEnclaves[signer] = EnclaveRecord({
            isAuthorized: true,
            registeredAt: block.timestamp,
            expiresAt: leaseExpiration,
            pcr0: pcr0Measurement
        });

        // Set as active primary enclave signer
        enclaveSigner = signer;
        authorizedSigners[signer] = true;

        emit EnclaveRegistered(signer, pcr0Measurement, att.timestamp, leaseExpiration);
        return signer;
    }

    // --- ITeeAuthenticator Verification ---

    /**
     * @notice Verifies an ECDSA signature against an authorized attested enclave signer.
     */
    function verifyEnclaveSignature(bytes32 digest, bytes calldata signature)
        external
        view
        override
        whenNotPaused
        returns (bool)
    {
        if (signature.length != 65) return false;

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        if (v < 27) {
            v += 27;
        }
        if (v != 27 && v != 28) {
            return false;
        }

        // secp256k1 high-s malleability defense
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E735E5A4761022201994C6D7098) {
            return false;
        }

        address recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0)) return false;

        return isSignerAuthorized(recovered);
    }

    /**
     * @notice Returns whether an address is currently an authorized enclave signer.
     */
    function isSignerAuthorized(address signer) public view override returns (bool) {
        if (paused) return false;

        if (useHardwareAttestation) {
            EnclaveRecord memory rec = registeredEnclaves[signer];
            return rec.isAuthorized && block.timestamp <= rec.expiresAt;
        } else {
            // Dev mode: check authorizedSigners map or active registered lease
            if (authorizedSigners[signer]) return true;
            EnclaveRecord memory rec = registeredEnclaves[signer];
            return rec.isAuthorized && block.timestamp <= rec.expiresAt;
        }
    }

    /**
     * @notice Returns the primary active enclave signer address.
     */
    function getEnclaveSigner() external view override returns (address) {
        return enclaveSigner;
    }
}
