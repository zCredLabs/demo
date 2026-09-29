// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ITeeAuthenticator} from "../interfaces/ITeeAuthenticator.sol";

/**
 * @title MockTeeAuthenticator
 * @notice Test harness simulating Horizen Vela AWS Nitro Enclave attestation and signature verification.
 * @dev Performs ECDSA ecrecover against an authorized enclave signer address.
 */
contract MockTeeAuthenticator is ITeeAuthenticator {
    address public enclaveSigner;
    mapping(address => bool) public authorizedSigners;
    bool public forceVerifyFailure;

    event EnclaveSignerUpdated(address indexed previousSigner, address indexed newSigner);

    constructor(address _initialSigner) {
        enclaveSigner = _initialSigner;
        authorizedSigners[_initialSigner] = true;
    }

    function setEnclaveSigner(address _signer) external {
        emit EnclaveSignerUpdated(enclaveSigner, _signer);
        authorizedSigners[enclaveSigner] = false;
        enclaveSigner = _signer;
        authorizedSigners[_signer] = true;
    }

    function setSignerAuthorized(address _signer, bool _authorized) external {
        authorizedSigners[_signer] = _authorized;
    }

    function setForceVerifyFailure(bool _force) external {
        forceVerifyFailure = _force;
    }

    function isSignerAuthorized(address _signer) public view override returns (bool) {
        return authorizedSigners[_signer];
    }

    function getEnclaveSigner() external view override returns (address) {
        return enclaveSigner;
    }

    function verifyEnclaveSignature(bytes32 digest, bytes calldata signature)
        external
        view
        override
        returns (bool)
    {
        if (forceVerifyFailure) return false;
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

        // Prevent signature malleability (secp256k1 standard high-s rejection)
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E735E5A4761022201994C6D7098) {
            return false;
        }

        address recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0)) return false;

        return authorizedSigners[recovered];
    }
}
