// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployGuardScript} from "../../script/DeployGuard.s.sol";
import {TradingGuard} from "../../src/TradingGuard.sol";

contract DeployGuardScriptTest is Test {
    uint256 constant TEST_PK = 0xBEEF;

    address constant CTF_EXCHANGE = 0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E;
    address constant NEG_RISK_CTF_EXCHANGE = 0xC5d563A36AE78145C45a50134d48A1215220f80a;
    address constant NEG_RISK_ADAPTER = 0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296;

    address public deployer;

    function setUp() public {
        vm.createSelectFork(vm.envString("POLYGON_RPC_URL"));
        deployer = vm.addr(TEST_PK);
        vm.setEnv("OWNER_PRIVATE_KEY", vm.toString(TEST_PK));
    }

    function test_script_deploysFactoryAndGuard() public {
        DeployGuardScript script = new DeployGuardScript();
        script.run();
        assertTrue(address(script.factory()).code.length > 0);
        assertTrue(address(script.guard()).code.length > 0);
    }

    function test_script_guardOwnedByDeployer() public {
        DeployGuardScript script = new DeployGuardScript();
        script.run();
        assertEq(script.guard().owner(), deployer);
    }

    function test_script_guardHasCorrectWhitelist() public {
        DeployGuardScript script = new DeployGuardScript();
        script.run();
        TradingGuard guard = script.guard();
        assertTrue(guard.whitelisted(CTF_EXCHANGE));
        assertTrue(guard.whitelisted(NEG_RISK_CTF_EXCHANGE));
        assertTrue(guard.whitelisted(NEG_RISK_ADAPTER));
    }
}
