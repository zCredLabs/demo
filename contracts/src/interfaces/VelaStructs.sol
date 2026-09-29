// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ITokenAllowlist} from "./ITokenAllowlist.sol";

// Sentinel address representing native ETH as the token.
address constant ETH_TOKEN = address(0);

/// @title VelaStructs
/// @notice Shared struct definitions matching Horizen Vela v0.2.0 on-chain layout.
///         Mirrors the `Structs` contract deployed in the Vela Docker devnet.
library VelaStructs {
    enum RequestType {
        DEPLOYAPP,
        PROCESS,
        DEANONYMIZATION,
        ASSOCIATEKEY,
        TRUSTPROCESS
    }

    enum RequestResult {
        COMPLETED,
        FAILED
    }

    enum ErrorCode {
        NO_ERROR,
        UNKNOWN,
        INTERNAL,
        APPLICATION_ALREADY_DEPLOYED,
        FUNCTION_NOT_FOUND,
        DEPOSIT_FAILED,
        REQUEST_FUNC_FAILED,
        APP_NOT_DEPLOYED,
        WRONG_KEY_SENT,
        PUB_KEY_NOT_REGISTERED,
        NO_REPORT_DATA_FOUND,
        WASM_INTERNAL,
        INSUFFICIENT_FUEL
    }

    struct PendingRequest {
        uint256 timestamp;
        address tokenAddress;
        uint256 assetAmount;
        uint256 maxFeeValue;
        bytes32 requestId;
        bytes payload;
        address sender;
        address facilitator;
        uint64 applicationId;
        uint8 protocolVersion;
        RequestType requestType;
    }

    struct WithdrawalRequest {
        address tokenAddress;
        address payable receiver;
        uint256 amount;
    }

    /// @notice Application-level (non-encrypted, on-chain visible) events from WASM guest.
    /// @dev  `events[i]` is raw bytes of the i-th app event;
    ///       `subTypes[i]` is the corresponding on-chain `bytes32` subtype index.
    struct EventData {
        bytes[] events;
        bytes32[] subTypes;
    }

    struct TokenAndAmount {
        address token;
        uint256 amount;
    }
}
