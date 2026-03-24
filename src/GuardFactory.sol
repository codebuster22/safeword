// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TradingGuard} from "./TradingGuard.sol";

contract GuardFactory {
    // --- Events ---
    event GuardDeployed(address indexed guard, address indexed owner, uint256 indexed nonce);

    // --- State ---
    uint256 public deployCount;

    // --- Functions ---
    function deploy(address initialOwner, address[] calldata initialWhitelist) external returns (address guard) {
        deployCount++;
        bytes32 salt = keccak256(abi.encode(msg.sender, deployCount));
        guard = address(new TradingGuard{salt: salt}(initialOwner, initialWhitelist));
        emit GuardDeployed(guard, initialOwner, deployCount);
    }

    function deploy(address initialOwner, address[] calldata initialWhitelist, bytes32 salt)
        external
        returns (address guard)
    {
        deployCount++;
        guard = address(new TradingGuard{salt: salt}(initialOwner, initialWhitelist));
        emit GuardDeployed(guard, initialOwner, deployCount);
    }

    function computeAddress(address initialOwner, address[] calldata initialWhitelist, bytes32 salt)
        external
        view
        returns (address)
    {
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(type(TradingGuard).creationCode, abi.encode(initialOwner, initialWhitelist))
        );
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash))))
        );
    }
}
