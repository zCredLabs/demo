// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IProcessorEndpoint} from "../interfaces/IProcessorEndpoint.sol";
import {ITokenAllowlist} from "../interfaces/ITokenAllowlist.sol";
import {VelaStructs} from "../interfaces/VelaStructs.sol";
import {ITrigger} from "../VelaZcredTrigger.sol";

/**
 * @title MockProcessorEndpoint
 * @notice Minimal mock of Horizen Vela v0.2.0 ProcessorEndpoint for local Foundry testing.
 * @dev Simulates enclave state updates and trigger callbacks (execute → withdraw → getTrustProcessPayload).
 */
contract MockTokenAllowlist is ITokenAllowlist {
    address[] private _tokens;

    function addAllowedToken(address token) external override {
        _tokens.push(token);
        emit TokenAllowed(token);
    }

    function removeAllowedToken(address token) external override {
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == token) {
                _tokens[i] = _tokens[_tokens.length - 1];
                _tokens.pop();
                emit TokenRemoved(token);
                return;
            }
        }
    }

    function isAllowedToken(address token) external view override returns (bool) {
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == token) return true;
        }
        return token == address(0); // ETH always allowed
    }

    function getAllowedTokens() external view override returns (address[] memory) {
        return _tokens;
    }
}

contract MockProcessorEndpoint is IProcessorEndpoint {
    MockTokenAllowlist public immutable _tokenAllowlist;
    uint64 public nextAppId = 1;

    event TriggerExecuted(address indexed trigger, bool success);

    constructor() {
        _tokenAllowlist = new MockTokenAllowlist();
    }

    function tokenAllowlist() external view override returns (ITokenAllowlist) {
        return _tokenAllowlist;
    }

    function DEPLOYER_ROLE() external pure override returns (bytes32) {
        return keccak256("DEPLOYER_ROLE");
    }

    function UPDATE_STATUS_ROLE() external pure override returns (bytes32) {
        return keccak256("UPDATE_STATUS_ROLE");
    }

    function hasRole(bytes32, address) external pure override returns (bool) {
        return true;
    }

    function submitDeployRequest(uint8, bytes calldata) external override {}

    function submitDeployRequestWithTrigger(uint8, bytes calldata, address) external override {}

    function submitRequest(
        uint64,
        uint8,
        VelaStructs.RequestType,
        bytes calldata,
        address,
        uint256,
        uint256
    ) external payable override {}

    /**
     * @notice Simulates Vela stateUpdate executing a trigger callback.
     * @param trigger  The trigger contract address.
     * @param events   Raw attestation payloads (bytes[] array).
     * @param subTypes Corresponding bytes32 subtypes.
     */
    function executeTrigger(
        address trigger,
        bytes[] calldata events,
        bytes32[] calldata subTypes
    ) external returns (bool success) {
        VelaStructs.EventData memory eventData = VelaStructs.EventData({
            events: events,
            subTypes: subTypes
        });
        ITrigger(trigger).execute(eventData);
        emit TriggerExecuted(trigger, true);
        return true;
    }
}
