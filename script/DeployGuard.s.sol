// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {GuardFactory} from "../src/GuardFactory.sol";
import {TradingGuard} from "../src/TradingGuard.sol";

/// @title DeployGuard — Deploys GuardFactory + a standalone TradingGuard for contract verification.
contract DeployGuardScript is Script {
    // Polymarket contract addresses (Polygon Mainnet)
    address constant CTF_EXCHANGE = 0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E;
    address constant NEG_RISK_CTF_EXCHANGE = 0xC5d563A36AE78145C45a50134d48A1215220f80a;
    address constant NEG_RISK_ADAPTER = 0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296;

    GuardFactory public factory;
    TradingGuard public guard;

    function run() external {
        uint256 ownerPk = vm.envUint("OWNER_PRIVATE_KEY");
        address deployer = vm.addr(ownerPk);

        console.log("=== DEPLOY ===");
        console.log("Deployer:", deployer);

        address[] memory whitelist = new address[](3);
        whitelist[0] = CTF_EXCHANGE;
        whitelist[1] = NEG_RISK_CTF_EXCHANGE;
        whitelist[2] = NEG_RISK_ADAPTER;

        vm.startBroadcast(ownerPk);

        factory = new GuardFactory();

        // Deploy a standalone TradingGuard so --verify picks it up.
        // Once verified, all factory-deployed guards inherit verification via similar-match.
        guard = new TradingGuard(deployer, whitelist);

        vm.stopBroadcast();

        console.log("Factory:", address(factory));
        console.log("TradingGuard (verification only):", address(guard));
        console.log("=== DONE ===");
    }
}
