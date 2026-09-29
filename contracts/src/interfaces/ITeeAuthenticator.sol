// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ITeeAuthenticator
 * @notice Horizen Vela Enclave Attestation & Signature Verifier Interface.
 * @dev Validates that signed data originates from an attested AWS Nitro Enclave
 *      with verified hardware measurements (PCR0, PCR1, PCR2).
 */
interface ITeeAuthenticator {
    /**
     * @notice Verifies an ECDSA signature against the active attested enclave signer.
     * @param digest The 32-byte cryptographic digest that was signed.
     * @param signature The 65-byte secp256k1 signature (r, s, v).
     * @return isValid True if the signature matches an authorized enclave signer.
     */
    function verifyEnclaveSignature(bytes32 digest, bytes calldata signature)
        external
        view
        returns (bool isValid);

    /**
     * @notice Returns whether an address is an authorized enclave signer.
     * @param signer The address to inspect.
     */
    function isSignerAuthorized(address signer) external view returns (bool);

    /**
     * @notice Returns the primary active enclave signer address.
     */
    function getEnclaveSigner() external view returns (address);
}
