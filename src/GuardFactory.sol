// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TradingGuard} from "./TradingGuard.sol";

contract GuardFactory {
    // --- Events ---
    event GuardDeployed(address indexed guard, address indexed owner, uint256 indexed nonceOrSalt);

    // --- State ---
    mapping(address => uint256) public deployCount;

    // --- Functions ---
    function deploy(address initialOwner, address[] calldata initialWhitelist) external returns (address guard) {
        uint256 nonce = ++deployCount[msg.sender];
        bytes32 salt = keccak256(abi.encode(msg.sender, nonce));
        guard = address(new TradingGuard{salt: salt}(initialOwner, initialWhitelist));
        emit GuardDeployed(guard, initialOwner, nonce);
    }

    function deploy(address initialOwner, address[] calldata initialWhitelist, bytes32 salt)
        external
        returns (address guard)
    {
        ++deployCount[msg.sender];
        bytes32 finalSalt = keccak256(abi.encode(msg.sender, salt));
        guard = address(new TradingGuard{salt: finalSalt}(initialOwner, initialWhitelist));
        emit GuardDeployed(guard, initialOwner, uint256(salt));
    }

    function computeAddress(address deployer, address initialOwner, address[] calldata initialWhitelist, bytes32 salt)
        external
        view
        returns (address)
    {
        bytes32 finalSalt = keccak256(abi.encode(deployer, salt));
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(type(TradingGuard).creationCode, abi.encode(initialOwner, initialWhitelist))
        );
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), finalSalt, bytecodeHash))))
        );
    }
}
