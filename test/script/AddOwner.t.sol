// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AddOwnerScript} from "../../script/AddOwner.s.sol";
import {IGnosisSafe} from "../../src/interfaces/IGnosisSafe.sol";

contract AddOwnerScriptTest is Test {
    uint256 constant TEST_PK = 0xBEEF;
    address constant SAFE_ADDR = 0x998679089cDc7A9a116937C720517C95dB6DBA75;

    IGnosisSafe public safe;
    address public testOwner;
    address public newOwner;

    function setUp() public {
        vm.createSelectFork(vm.envString("POLYGON_RPC_URL"));

        safe = IGnosisSafe(SAFE_ADDR);
        testOwner = vm.addr(TEST_PK);
        newOwner = makeAddr("newOwner");

        // Add testOwner as Safe owner so the script can sign
        vm.prank(SAFE_ADDR);
        safe.addOwnerWithThreshold(testOwner, 1);

        // Set env vars the script reads
        vm.setEnv("OWNER_PRIVATE_KEY", vm.toString(TEST_PK));
        vm.setEnv("SAFE_ADDRESS", vm.toString(SAFE_ADDR));
        vm.setEnv("NEW_OWNER", vm.toString(newOwner));
    }

    function test_script_addsNewOwner() public {
        assertFalse(safe.isOwner(newOwner));

        AddOwnerScript script = new AddOwnerScript();
        script.run();

        assertTrue(safe.isOwner(newOwner));
    }

    function test_script_keepsThresholdAndOriginalOwner() public {
        AddOwnerScript script = new AddOwnerScript();
        script.run();

        assertEq(safe.getThreshold(), 1);
        assertTrue(safe.isOwner(testOwner));
    }
}
