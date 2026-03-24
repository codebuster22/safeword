// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IGnosisSafe, Enum} from "../src/interfaces/IGnosisSafe.sol";

/// @title AddOwner — Adds a new owner to a Gnosis Safe while keeping threshold at 1.
/// @notice Calls addOwnerWithThreshold via execTransaction, signed by the current owner.
contract AddOwnerScript is Script {
    function run() external {
        // ── Load environment ──────────────────────────────────────────────
        uint256 ownerPk = vm.envUint("OWNER_PRIVATE_KEY");
        address safeAddress = vm.envAddress("SAFE_ADDRESS");
        address newOwner = vm.envAddress("NEW_OWNER");
        address ownerAddress = vm.addr(ownerPk);

        IGnosisSafe safe = IGnosisSafe(safeAddress);

        // ── Pre-flight checks ─────────────────────────────────────────────
        _preflight(safe, safeAddress, ownerAddress, newOwner);

        // ── Build, sign, execute ──────────────────────────────────────────
        bytes memory signature = _buildAndSign(safe, safeAddress, newOwner, ownerPk, ownerAddress);
        _execute(safe, safeAddress, newOwner, ownerPk, signature);

        // ── Post-flight verification ──────────────────────────────────────
        _verify(safe, ownerAddress, newOwner);
    }

    function _preflight(
        IGnosisSafe safe,
        address safeAddress,
        address ownerAddress,
        address newOwner
    ) internal view {
        address[] memory owners = safe.getOwners();
        uint256 threshold = safe.getThreshold();
        uint256 currentNonce = safe.nonce();

        console.log("=== PRE-FLIGHT ===");
        console.log("Safe:", safeAddress);
        console.log("Signer (derived from pk):", ownerAddress);
        console.log("New owner to add:", newOwner);
        console.log("Threshold:", threshold);
        console.log("Nonce:", currentNonce);
        console.log("Owner count:", owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            console.log("  owner[%d]: %s", i, owners[i]);
        }

        require(safe.isOwner(ownerAddress), "ABORT: signer is not a current Safe owner");
        require(!safe.isOwner(newOwner), "ABORT: new owner is already a Safe owner");
        require(threshold == 1, "ABORT: threshold is not 1, script only supports threshold=1");
    }

    function _buildAndSign(
        IGnosisSafe safe,
        address safeAddress,
        address newOwner,
        uint256 ownerPk,
        address ownerAddress
    ) internal view returns (bytes memory) {
        // addOwnerWithThreshold is on the Safe itself, so to = safeAddress.
        // The `authorized` modifier requires msg.sender == address(this),
        // which is satisfied when called via execTransaction (self-call).
        bytes memory innerCallData = abi.encodeWithSelector(
            IGnosisSafe.addOwnerWithThreshold.selector,
            newOwner,
            uint256(1) // keep threshold at 1
        );

        // Gas refund params are all 0: we pay gas normally via the broadcaster,
        // not through Safe's built-in gas refund mechanism.
        uint256 currentNonce = safe.nonce();
        bytes32 txHash = safe.getTransactionHash(
            safeAddress,                // to: self-call
            0,                          // value: no ETH
            innerCallData,              // data: addOwnerWithThreshold(newOwner, 1)
            Enum.Operation.Call, // operation: regular call (not delegatecall)
            0,                          // safeTxGas: 0 means use all available gas
            0,                          // baseGas: 0
            0,                          // gasPrice: 0 (disables gas refund)
            address(0),                 // gasToken: n/a when gasPrice=0
            address(0),                 // refundReceiver: n/a when gasPrice=0
            currentNonce                // _nonce: must match safe.nonce()
        );

        console.log("=== SIGNING ===");
        console.log("Transaction hash:");
        console.logBytes32(txHash);

        // vm.sign returns (v, r, s) where v is 27 or 28 (standard ECDSA).
        // Safe's checkSignatures does ecrecover(dataHash, v, r, s) for v in [27,30].
        // Signature format: r (32 bytes) || s (32 bytes) || v (1 byte) = 65 bytes.
        // For threshold=1, a single 65-byte signature is sufficient.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, txHash);

        console.log("Signature v:", v);

        // Sanity: verify signature recovers to the owner address
        address recovered = ecrecover(txHash, v, r, s);
        require(recovered == ownerAddress, "ABORT: signature does not recover to owner");
        console.log("Recovered signer:", recovered);

        return abi.encodePacked(r, s, v);
    }

    function _execute(
        IGnosisSafe safe,
        address safeAddress,
        address newOwner,
        uint256 ownerPk,
        bytes memory signature
    ) internal {
        bytes memory innerCallData = abi.encodeWithSelector(
            IGnosisSafe.addOwnerWithThreshold.selector,
            newOwner,
            uint256(1)
        );

        console.log("=== EXECUTING ===");
        vm.broadcast(ownerPk);
        bool success = safe.execTransaction(
            safeAddress,                    // to
            0,                              // value
            innerCallData,                  // data
            Enum.Operation.Call,     // operation
            0,                              // safeTxGas
            0,                              // baseGas
            0,                              // gasPrice
            address(0),                     // gasToken
            payable(address(0)),            // refundReceiver
            signature                       // signatures
        );
        require(success, "FAILED: execTransaction returned false");
    }

    function _verify(IGnosisSafe safe, address ownerAddress, address newOwner) internal view {
        console.log("=== VERIFICATION ===");

        require(safe.isOwner(newOwner), "FAILED: new owner not found after execution");
        require(safe.isOwner(ownerAddress), "FAILED: original owner removed unexpectedly");
        require(safe.getThreshold() == 1, "FAILED: threshold changed unexpectedly");

        address[] memory owners = safe.getOwners();
        console.log("Owner count:", owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            console.log("  owner[%d]: %s", i, owners[i]);
        }
        console.log("Threshold:", safe.getThreshold());
        console.log("=== DONE ===");
    }
}
