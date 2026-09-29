// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ITokenAllowlist} from "./ITokenAllowlist.sol";
import {VelaStructs} from "./VelaStructs.sol";

/// @title IProcessorEndpoint
/// @notice Horizen Vela v0.2.0 ProcessorEndpoint external interface (subset used by Zcred).
interface IProcessorEndpoint {
    // --- Events ---
    event RequestSubmitted(
        uint64 indexed applicationId,
        bytes32 indexed requestId,
        address indexed sender,
        address facilitator
    );
    event DeployRequestSubmitted(
        uint64 indexed applicationId,
        bytes32 indexed requestId,
        address indexed sender
    );
    event StateRootUpdate(bytes32 indexed newStateRoot);
    event AppEvent(
        uint64 indexed applicationId,
        bytes32 indexed requestId,
        bytes32 indexed subType,
        bytes data
    );

    // --- Errors ---
    error InvalidProtocolVersion();
    error InvalidRequestType();
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    // --- Role Constants ---
    function DEPLOYER_ROLE() external view returns (bytes32);
    function UPDATE_STATUS_ROLE() external view returns (bytes32);

    // --- Token Allowlist ---
    function tokenAllowlist() external view returns (ITokenAllowlist);

    // --- Deploy ---
    function submitDeployRequest(
        uint8 protocolVersion,
        bytes calldata payload
    ) external;

    function submitDeployRequestWithTrigger(
        uint8 protocolVersion,
        bytes calldata payload,
        address trigger
    ) external;

    // --- Process ---
    function submitRequest(
        uint64 applicationId,
        uint8 protocolVersion,
        VelaStructs.RequestType requestType,
        bytes calldata payload,
        address tokenAddress,
        uint256 assetAmount,
        uint256 maxFeeValue
    ) external payable;

    // --- Admin ---
    function hasRole(bytes32 role, address account) external view returns (bool);
}
