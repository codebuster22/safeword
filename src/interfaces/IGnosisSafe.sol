// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.20;

contract Enum {
    enum Operation {Call, DelegateCall}
}

/// @title IGnosisSafe - Minimal interface for GnosisSafeL2 v1.3.0
/// @notice Extracted from verified source at polygonscan.com/address/0xe51abdf814f8854941b9fe8e3a4f65cab4e7a4a8
interface IGnosisSafe {

    /// @notice Returns the current transaction nonce.
    function nonce() external view returns (uint256);

    /// @notice Returns the pre-image of the transaction hash (EIP-712 digest).
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32);

    /// @notice Executes a Safe transaction confirmed by required number of owners.
    /// @return success True if the transaction was successful.
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success);

    /// @notice Adds the owner `owner` to the Safe and updates the threshold to `_threshold`.
    function addOwnerWithThreshold(address owner, uint256 _threshold) external;

    /// @notice Returns array of owners.
    function getOwners() external view returns (address[] memory);

    /// @notice Returns whether `owner` is an owner of the Safe.
    function isOwner(address owner) external view returns (bool);

    /// @notice Returns the number of required confirmations.
    function getThreshold() external view returns (uint256);

    /// @notice Sets a guard that checks transactions before and after execution.
    function setGuard(address guard) external;
}
