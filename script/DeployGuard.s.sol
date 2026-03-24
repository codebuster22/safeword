// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IGnosisSafe, Enum} from "../src/interfaces/IGnosisSafe.sol";
import {GuardFactory} from "../src/GuardFactory.sol";
import {TradingGuard} from "../src/TradingGuard.sol";

/// @title DeployGuard — Deploys GuardFactory + TradingGuard, optionally sets guard on Safe.
contract DeployGuardScript is Script {
    // Polymarket contract addresses (Polygon Mainnet)
    address constant CTF_EXCHANGE = 0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E;
    address constant NEG_RISK_CTF_EXCHANGE = 0xC5d563A36AE78145C45a50134d48A1215220f80a;
    address constant NEG_RISK_ADAPTER = 0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296;

    function run() external {
        // ── Load environment ──────────────────────────────────────────────
        uint256 ownerPk = vm.envUint("OWNER_PRIVATE_KEY");
        address adminAddress = vm.envAddress("ADMIN_ADDRESS");
        address ownerAddress = vm.addr(ownerPk);

        console.log("=== DEPLOY GUARD ===");
        console.log("Deployer/Signer:", ownerAddress);
        console.log("Admin (Guard owner):", adminAddress);

        // ── Build whitelist ───────────────────────────────────────────────
        address[] memory whitelist = new address[](3);
        whitelist[0] = CTF_EXCHANGE;
        whitelist[1] = NEG_RISK_CTF_EXCHANGE;
        whitelist[2] = NEG_RISK_ADAPTER;

        // ── Deploy factory + guard ────────────────────────────────────────
        vm.startBroadcast(ownerPk);
        GuardFactory factory = new GuardFactory();
        address guard = factory.deploy(adminAddress, whitelist);
        vm.stopBroadcast();

        console.log("Factory deployed:", address(factory));
        console.log("Guard deployed:", guard);
        console.log("Guard owner:", TradingGuard(guard).owner());

        // ── Optionally set guard on Safe ──────────────────────────────────
        bool setGuard = vm.envOr("SET_GUARD", false);
        if (setGuard) {
            address safeAddress = vm.envAddress("SAFE_ADDRESS");
            _setGuardOnSafe(safeAddress, guard, ownerPk, ownerAddress);
        }

        console.log("=== DONE ===");
    }

    function _setGuardOnSafe(
        address safeAddress,
        address guard,
        uint256 ownerPk,
        address ownerAddress
    ) internal {
        IGnosisSafe safe = IGnosisSafe(safeAddress);

        // Pre-flight
        console.log("=== SET GUARD ON SAFE ===");
        console.log("Safe:", safeAddress);
        require(safe.isOwner(ownerAddress), "ABORT: signer is not a Safe owner");
        require(safe.getThreshold() == 1, "ABORT: threshold is not 1");

        // Build inner call: safe.setGuard(guard)
        bytes memory innerCallData = abi.encodeWithSelector(IGnosisSafe.setGuard.selector, guard);

        // Sign
        uint256 currentNonce = safe.nonce();
        bytes32 txHash = safe.getTransactionHash(
            safeAddress, // to: self-call
            0, // value
            innerCallData, // data
            Enum.Operation.Call, // operation
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            address(0), // refundReceiver
            currentNonce
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, txHash);
        address recovered = ecrecover(txHash, v, r, s);
        require(recovered == ownerAddress, "ABORT: signature recovery failed");

        bytes memory signature = abi.encodePacked(r, s, v);

        // Execute
        vm.broadcast(ownerPk);
        bool success = safe.execTransaction(
            safeAddress,
            0,
            innerCallData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signature
        );
        require(success, "FAILED: execTransaction returned false");
        console.log("Guard set on Safe successfully");
    }
}
