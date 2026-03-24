// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
import {DeployGuardScript} from "../../script/DeployGuard.s.sol";
import {GuardFactory} from "../../src/GuardFactory.sol";
import {TradingGuard} from "../../src/TradingGuard.sol";
import {IGnosisSafe} from "../../src/interfaces/IGnosisSafe.sol";

contract DeployGuardScriptTest is Test {
    uint256 constant TEST_PK = 0xBEEF;

    address constant SAFE_ADDR = 0x998679089cDc7A9a116937C720517C95dB6DBA75;
    address constant CTF_EXCHANGE = 0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E;
    address constant NEG_RISK_CTF_EXCHANGE = 0xC5d563A36AE78145C45a50134d48A1215220f80a;
    address constant NEG_RISK_ADAPTER = 0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296;

    bytes32 constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

    IGnosisSafe public safe;
    address public testOwner;

    function setUp() public {
        vm.createSelectFork(vm.envString("POLYGON_RPC_URL"));

        safe = IGnosisSafe(SAFE_ADDR);
        testOwner = vm.addr(TEST_PK);

        // Add testOwner as Safe owner so the script can execute setGuard
        vm.prank(SAFE_ADDR);
        safe.addOwnerWithThreshold(testOwner, 1);

        // Set env vars the script reads (reset SET_GUARD — vm.setEnv persists across tests)
        vm.setEnv("OWNER_PRIVATE_KEY", vm.toString(TEST_PK));
        vm.setEnv("ADMIN_ADDRESS", vm.toString(testOwner));
        vm.setEnv("SET_GUARD", "false");
    }

    function _runScriptAndGetGuard() internal returns (TradingGuard) {
        vm.recordLogs();
        DeployGuardScript script = new DeployGuardScript();
        script.run();

        // Parse GuardDeployed event to find the guard address
        Vm.Log[] memory logs = vm.getRecordedLogs();
        address guardAddr;
        for (uint256 i = 0; i < logs.length; i++) {
            // GuardDeployed(address indexed guard, address indexed owner, uint256 indexed nonce)
            if (logs[i].topics[0] == GuardFactory.GuardDeployed.selector) {
                guardAddr = address(uint160(uint256(logs[i].topics[1])));
                break;
            }
        }
        require(guardAddr != address(0), "GuardDeployed event not found");
        return TradingGuard(guardAddr);
    }

    function test_script_deploysFactoryAndGuard() public {
        TradingGuard guard = _runScriptAndGetGuard();
        assertTrue(address(guard).code.length > 0);
    }

    function test_script_guardHasCorrectOwner() public {
        TradingGuard guard = _runScriptAndGetGuard();
        assertEq(guard.owner(), testOwner);
    }

    function test_script_guardHasCorrectWhitelist() public {
        TradingGuard guard = _runScriptAndGetGuard();
        assertTrue(guard.whitelisted(CTF_EXCHANGE));
        assertTrue(guard.whitelisted(NEG_RISK_CTF_EXCHANGE));
        assertTrue(guard.whitelisted(NEG_RISK_ADAPTER));
    }

    function test_script_setGuardOnSafe() public {
        vm.setEnv("SET_GUARD", "true");
        vm.setEnv("SAFE_ADDRESS", vm.toString(SAFE_ADDR));

        TradingGuard guard = _runScriptAndGetGuard();

        bytes32 guardSlot = vm.load(SAFE_ADDR, GUARD_STORAGE_SLOT);
        assertEq(guardSlot, bytes32(uint256(uint160(address(guard)))));
    }
}
