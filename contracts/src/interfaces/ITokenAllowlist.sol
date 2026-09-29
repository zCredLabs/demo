// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title ITokenAllowlist
/// @notice Interface for managing a global ERC-20 token allowlist (Horizen Vela v0.2.0).
interface ITokenAllowlist {
    event TokenAllowed(address indexed token);
    event TokenRemoved(address indexed token);

    error TokenAddressCantBeZero();
    error NotAContract();
    error TokenNotAllowed();

    function addAllowedToken(address token) external;
    function removeAllowedToken(address token) external;
    function isAllowedToken(address token) external view returns (bool);
    function getAllowedTokens() external view returns (address[] memory);
}
