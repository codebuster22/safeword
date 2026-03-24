// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GuardFactory} from "../src/GuardFactory.sol";
import {TradingGuard} from "../src/TradingGuard.sol";
import {IGuard} from "../src/interfaces/IGuard.sol";

contract GuardFactoryTest is Test {
    GuardFactory public factory;

    address public guardOwner = makeAddr("guardOwner");
    address public whitelistedA = makeAddr("whitelistedA");
    address public whitelistedB = makeAddr("whitelistedB");

    address[] public whitelist;

    function setUp() public {
        factory = new GuardFactory();
        whitelist.push(whitelistedA);
        whitelist.push(whitelistedB);
    }

    // ═══════════════════════════════════════════════════
    // Deploy (auto-salt)
    // ═══════════════════════════════════════════════════

    function test_deploy_createsGuard() public {
        address guard = factory.deploy(guardOwner, whitelist);
        assertTrue(guard != address(0));
        assertEq(TradingGuard(guard).owner(), guardOwner);
    }

    function test_deploy_setsWhitelist() public {
        address guard = factory.deploy(guardOwner, whitelist);
        assertTrue(TradingGuard(guard).whitelisted(whitelistedA));
        assertTrue(TradingGuard(guard).whitelisted(whitelistedB));
    }

    function test_deploy_incrementsCount() public {
        factory.deploy(guardOwner, whitelist);
        assertEq(factory.deployCount(), 1);
    }

    function test_deploy_emitsEvent() public {
        vm.expectEmit(false, true, true, false);
        emit GuardFactory.GuardDeployed(address(0), guardOwner, 1);
        factory.deploy(guardOwner, whitelist);
    }

    function test_deploy_multipleGuards() public {
        address g1 = factory.deploy(guardOwner, whitelist);
        address g2 = factory.deploy(guardOwner, whitelist);
        address g3 = factory.deploy(guardOwner, whitelist);

        assertEq(factory.deployCount(), 3);
        assertTrue(g1 != g2 && g2 != g3 && g1 != g3);
    }

    // ═══════════════════════════════════════════════════
    // Deploy (explicit salt) + computeAddress
    // ═══════════════════════════════════════════════════

    function test_deploy_withSalt_deterministic() public {
        bytes32 salt = keccak256("test-salt");
        address predicted = factory.computeAddress(guardOwner, whitelist, salt);
        address actual = factory.deploy(guardOwner, whitelist, salt);
        assertEq(predicted, actual);
    }

    function test_deploy_withSalt_differentSalts() public {
        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");
        address g1 = factory.deploy(guardOwner, whitelist, salt1);
        address g2 = factory.deploy(guardOwner, whitelist, salt2);
        assertTrue(g1 != g2);
    }

    function test_deploy_autoSalt_different() public {
        address g1 = factory.deploy(guardOwner, whitelist);
        address g2 = factory.deploy(guardOwner, whitelist);
        assertTrue(g1 != g2);
    }

    function test_computeAddress_matchesActual() public {
        bytes32 salt = keccak256("compute-test");
        address predicted = factory.computeAddress(guardOwner, whitelist, salt);
        address actual = factory.deploy(guardOwner, whitelist, salt);
        assertEq(predicted, actual);
    }

    // ═══════════════════════════════════════════════════
    // Deployed guard state
    // ═══════════════════════════════════════════════════

    function test_deploy_guardStartsInTradingMode() public {
        address guard = factory.deploy(guardOwner, whitelist);
        assertEq(uint8(TradingGuard(guard).mode()), uint8(TradingGuard.Mode.Trading));
    }

    function test_deploy_guardSupportsInterface() public {
        address guard = factory.deploy(guardOwner, whitelist);
        assertTrue(TradingGuard(guard).supportsInterface(type(IGuard).interfaceId));
    }
}
