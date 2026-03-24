// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TradingGuard} from "../src/TradingGuard.sol";
import {IGuard} from "../src/interfaces/IGuard.sol";
import {IGnosisSafe, Enum} from "../src/interfaces/IGnosisSafe.sol";
import {MockSafe} from "./mocks/MockSafe.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TradingGuardTest is Test {
    TradingGuard public guard;
    MockSafe public mockSafe;

    address public owner = makeAddr("owner");
    address public botKey = makeAddr("botKey");
    address public whitelistedTarget = makeAddr("whitelistedTarget");
    address public randomAddr = makeAddr("randomAddr");

    address[] public initialWhitelist;

    function setUp() public {
        initialWhitelist.push(whitelistedTarget);
        guard = new TradingGuard(owner, initialWhitelist);
        mockSafe = new MockSafe();
    }

    // ═══════════════════════════════════════════════════
    // Step 1: ERC-165 + Interface ID
    // ═══════════════════════════════════════════════════

    function test_supportsInterface_guard() public view {
        assertTrue(guard.supportsInterface(type(IGuard).interfaceId));
    }

    function test_supportsInterface_erc165() public view {
        assertTrue(guard.supportsInterface(0x01ffc9a7));
    }

    function test_supportsInterface_random() public view {
        assertFalse(guard.supportsInterface(0xdeadbeef));
    }

    function test_guardInterfaceId() public pure {
        assertEq(type(IGuard).interfaceId, bytes4(0xe6d7a83a));
    }

    // ═══════════════════════════════════════════════════
    // Step 2: Constructor + State
    // ═══════════════════════════════════════════════════

    function test_constructor_setsOwner() public view {
        assertEq(guard.owner(), owner);
    }

    function test_constructor_startsInTradingMode() public view {
        assertEq(uint8(guard.mode()), uint8(TradingGuard.Mode.Trading));
    }

    function test_constructor_setsWhitelist() public view {
        assertTrue(guard.whitelisted(whitelistedTarget));
    }

    function test_constructor_nonWhitelistedIsFalse() public view {
        assertFalse(guard.whitelisted(randomAddr));
    }

    function test_constructor_revertsOnZeroOwner() public {
        address[] memory emptyList = new address[](0);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new TradingGuard(address(0), emptyList);
    }

    function test_constructor_emptyWhitelist() public {
        address[] memory emptyList = new address[](0);
        TradingGuard g = new TradingGuard(owner, emptyList);
        assertEq(uint8(g.mode()), uint8(TradingGuard.Mode.Trading));
        assertFalse(g.whitelisted(whitelistedTarget));
    }

    function test_constructor_emitsWhitelistEvents() public {
        address[] memory list = new address[](2);
        list[0] = makeAddr("a");
        list[1] = makeAddr("b");

        vm.expectEmit(true, false, false, true);
        emit TradingGuard.WhitelistUpdated(list[0], true);
        vm.expectEmit(true, false, false, true);
        emit TradingGuard.WhitelistUpdated(list[1], true);
        new TradingGuard(owner, list);
    }

    // ═══════════════════════════════════════════════════
    // Step 3: Trading Mode (checkTransaction)
    // ═══════════════════════════════════════════════════

    function test_trading_allowsWhitelistedCall() public {
        mockSafe.execThroughGuard(
            guard, whitelistedTarget, 0, "", Enum.Operation.Call, botKey
        );
    }

    function test_trading_blocksDelegatecall() public {
        vm.expectRevert(TradingGuard.DelegatecallBlocked.selector);
        mockSafe.execThroughGuard(
            guard, whitelistedTarget, 0, "", Enum.Operation.DelegateCall, botKey
        );
    }

    function test_trading_allowsEthTransfer() public {
        mockSafe.execThroughGuard(
            guard, whitelistedTarget, 1 ether, "", Enum.Operation.Call, botKey
        );
    }

    function test_trading_blocksSelfCall() public {
        vm.expectRevert(TradingGuard.SelfCallBlocked.selector);
        mockSafe.execThroughGuard(
            guard, address(mockSafe), 0, "", Enum.Operation.Call, botKey
        );
    }

    function test_trading_blocksNonWhitelisted() public {
        vm.expectRevert(abi.encodeWithSelector(TradingGuard.TargetNotWhitelisted.selector, randomAddr));
        mockSafe.execThroughGuard(
            guard, randomAddr, 0, "", Enum.Operation.Call, botKey
        );
    }

    function test_trading_anyoneCanCallWhitelisted() public {
        // botKey can call
        mockSafe.execThroughGuard(
            guard, whitelistedTarget, 0, "", Enum.Operation.Call, botKey
        );
        // owner can call
        mockSafe.execThroughGuard(
            guard, whitelistedTarget, 0, "", Enum.Operation.Call, owner
        );
    }

    function test_trading_allowsArbitraryCalldata() public {
        bytes memory data = abi.encodeWithSignature("someFunction(uint256)", 42);
        mockSafe.execThroughGuard(
            guard, whitelistedTarget, 0, data, Enum.Operation.Call, botKey
        );
    }

    // ═══════════════════════════════════════════════════
    // Step 4: Unlocked Mode
    // ═══════════════════════════════════════════════════

    function test_unlocked_allowsAnyTransaction() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        mockSafe.execThroughGuard(
            guard, randomAddr, 0, "", Enum.Operation.Call, botKey
        );
    }

    function test_unlocked_staysUnlockedAfterTransaction() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        mockSafe.execThroughGuard(
            guard, randomAddr, 0, "", Enum.Operation.Call, botKey
        );
        assertEq(uint8(guard.mode()), uint8(TradingGuard.Mode.Unlocked));
    }

    function test_unlocked_allowsAnyTarget() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        mockSafe.execThroughGuard(
            guard, randomAddr, 0, "", Enum.Operation.Call, botKey
        );
    }

    function test_unlocked_allowsSelfCall() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        mockSafe.execThroughGuard(
            guard, address(mockSafe), 0, "", Enum.Operation.Call, botKey
        );
    }

    function test_unlocked_allowsDelegatecall() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        mockSafe.execThroughGuard(
            guard, randomAddr, 0, "", Enum.Operation.DelegateCall, botKey
        );
    }

    function test_unlocked_allowsEthTransfer() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        mockSafe.execThroughGuard(
            guard, randomAddr, 1 ether, "", Enum.Operation.Call, botKey
        );
    }

    function test_unlocked_allowsMultipleTransactions() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        mockSafe.execThroughGuard(
            guard, randomAddr, 0, "", Enum.Operation.Call, botKey
        );
        mockSafe.execThroughGuard(
            guard, randomAddr, 1 ether, "", Enum.Operation.DelegateCall, owner
        );
        assertEq(uint8(guard.mode()), uint8(TradingGuard.Mode.Unlocked));
    }

    // --- switchToUnlocked / switchToTrading admin functions ---

    function test_switchToUnlocked_onlyOwner() public {
        vm.prank(botKey);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, botKey));
        guard.switchToUnlocked();
    }

    function test_switchToUnlocked_setsMode() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        assertEq(uint8(guard.mode()), uint8(TradingGuard.Mode.Unlocked));
    }

    function test_switchToTrading_onlyOwner() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        vm.prank(botKey);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, botKey));
        guard.switchToTrading();
    }

    function test_switchToTrading_setsMode() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        vm.prank(owner);
        guard.switchToTrading();
        assertEq(uint8(guard.mode()), uint8(TradingGuard.Mode.Trading));
    }

    // ═══════════════════════════════════════════════════
    // Step 5: FailSafe Mode
    // ═══════════════════════════════════════════════════

    function test_failSafe_blocksAllTransactions() public {
        vm.prank(owner);
        guard.switchToFailSafe();
        vm.expectRevert(TradingGuard.FailSafeActive.selector);
        mockSafe.execThroughGuard(
            guard, whitelistedTarget, 0, "", Enum.Operation.Call, botKey
        );
    }

    function test_failSafe_blocksOwner() public {
        vm.prank(owner);
        guard.switchToFailSafe();
        vm.expectRevert(TradingGuard.FailSafeActive.selector);
        mockSafe.execThroughGuard(
            guard, whitelistedTarget, 0, "", Enum.Operation.Call, owner
        );
    }

    function test_failSafe_overridesUnlocked() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        vm.prank(owner);
        guard.switchToFailSafe();
        vm.expectRevert(TradingGuard.FailSafeActive.selector);
        mockSafe.execThroughGuard(
            guard, randomAddr, 0, "", Enum.Operation.Call, owner
        );
    }

    function test_switchToFailSafe_onlyOwner() public {
        vm.prank(botKey);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, botKey));
        guard.switchToFailSafe();
    }

    function test_switchToFailSafe_fromTrading() public {
        vm.prank(owner);
        guard.switchToFailSafe();
        assertEq(uint8(guard.mode()), uint8(TradingGuard.Mode.FailSafe));
    }

    function test_switchToFailSafe_fromUnlocked() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        vm.prank(owner);
        guard.switchToFailSafe();
        assertEq(uint8(guard.mode()), uint8(TradingGuard.Mode.FailSafe));
    }

    function test_switchToTrading_onlyOwner_fromFailSafe() public {
        vm.prank(owner);
        guard.switchToFailSafe();
        vm.prank(botKey);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, botKey));
        guard.switchToTrading();
    }

    function test_switchToTrading_fromFailSafe() public {
        vm.prank(owner);
        guard.switchToFailSafe();
        vm.prank(owner);
        guard.switchToTrading();
        assertEq(uint8(guard.mode()), uint8(TradingGuard.Mode.Trading));
    }

    // ═══════════════════════════════════════════════════
    // Step 6: Whitelist Management
    // ═══════════════════════════════════════════════════

    function test_setWhitelisted_onlyOwner() public {
        vm.prank(botKey);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, botKey));
        guard.setWhitelisted(randomAddr, true);
    }

    function test_setWhitelisted_addsAddress() public {
        vm.prank(owner);
        guard.setWhitelisted(randomAddr, true);
        assertTrue(guard.whitelisted(randomAddr));
    }

    function test_setWhitelisted_removesAddress() public {
        vm.prank(owner);
        guard.setWhitelisted(whitelistedTarget, false);
        assertFalse(guard.whitelisted(whitelistedTarget));
    }

    function test_setWhitelisted_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit TradingGuard.WhitelistUpdated(randomAddr, true);
        guard.setWhitelisted(randomAddr, true);
    }

    function test_setWhitelisted_worksInTradingMode() public {
        vm.prank(owner);
        guard.setWhitelisted(randomAddr, true);
        assertTrue(guard.whitelisted(randomAddr));
    }

    function test_setWhitelisted_worksInUnlockedMode() public {
        vm.prank(owner);
        guard.switchToUnlocked();
        vm.prank(owner);
        guard.setWhitelisted(randomAddr, true);
        assertTrue(guard.whitelisted(randomAddr));
    }

    function test_setWhitelisted_worksInFailSafeMode() public {
        vm.prank(owner);
        guard.switchToFailSafe();
        vm.prank(owner);
        guard.setWhitelisted(randomAddr, true);
        assertTrue(guard.whitelisted(randomAddr));
    }

    function test_modeChanged_emitsOnAllTransitions() public {
        // Trading -> Unlocked
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit TradingGuard.ModeChanged(TradingGuard.Mode.Trading, TradingGuard.Mode.Unlocked);
        guard.switchToUnlocked();

        // Unlocked -> Trading
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit TradingGuard.ModeChanged(TradingGuard.Mode.Unlocked, TradingGuard.Mode.Trading);
        guard.switchToTrading();

        // Trading -> FailSafe
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit TradingGuard.ModeChanged(TradingGuard.Mode.Trading, TradingGuard.Mode.FailSafe);
        guard.switchToFailSafe();

        // FailSafe -> Trading
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit TradingGuard.ModeChanged(TradingGuard.Mode.FailSafe, TradingGuard.Mode.Trading);
        guard.switchToTrading();

        // Unlocked -> FailSafe
        vm.prank(owner);
        guard.switchToUnlocked();
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit TradingGuard.ModeChanged(TradingGuard.Mode.Unlocked, TradingGuard.Mode.FailSafe);
        guard.switchToFailSafe();
    }

    // ═══════════════════════════════════════════════════
    // Step 7: Bypass Protection Tests
    // ═══════════════════════════════════════════════════

    function test_bypass_delegatecallMultisend() public {
        // DelegateCall to whitelisted target is still blocked in Trading mode
        vm.expectRevert(TradingGuard.DelegatecallBlocked.selector);
        mockSafe.execThroughGuard(
            guard, whitelistedTarget, 0, "", Enum.Operation.DelegateCall, botKey
        );
    }

    function test_bypass_selfCallSetGuard() public {
        bytes memory data = abi.encodeWithSelector(IGnosisSafe.setGuard.selector, address(0));
        vm.expectRevert(TradingGuard.SelfCallBlocked.selector);
        mockSafe.execThroughGuard(
            guard, address(mockSafe), 0, data, Enum.Operation.Call, botKey
        );
    }

    function test_bypass_selfCallAddOwner() public {
        address attacker = makeAddr("attacker");
        bytes memory data = abi.encodeWithSelector(IGnosisSafe.addOwnerWithThreshold.selector, attacker, 1);
        vm.expectRevert(TradingGuard.SelfCallBlocked.selector);
        mockSafe.execThroughGuard(
            guard, address(mockSafe), 0, data, Enum.Operation.Call, botKey
        );
    }

    function test_bypass_selfCallEnableModule() public {
        address attacker = makeAddr("attacker");
        bytes memory data = abi.encodeWithSignature("enableModule(address)", attacker);
        vm.expectRevert(TradingGuard.SelfCallBlocked.selector);
        mockSafe.execThroughGuard(
            guard, address(mockSafe), 0, data, Enum.Operation.Call, botKey
        );
    }

    function test_bypass_valueOnWhitelistedTarget_allowed() public {
        // ETH transfers are allowed on Polygon (MATIC is cheap)
        mockSafe.execThroughGuard(
            guard, whitelistedTarget, 1 ether, "", Enum.Operation.Call, botKey
        );
    }

    function test_bypass_unlockRequiresManualLock() public {
        // Owner unlocks, multiple txs go through, stays unlocked until manually locked
        vm.prank(owner);
        guard.switchToUnlocked();
        mockSafe.execThroughGuard(
            guard, randomAddr, 0, "", Enum.Operation.Call, botKey
        );
        mockSafe.execThroughGuard(
            guard, randomAddr, 0, "", Enum.Operation.Call, botKey
        );
        assertEq(uint8(guard.mode()), uint8(TradingGuard.Mode.Unlocked));
        // After manual lock, Trading restrictions apply again
        vm.prank(owner);
        guard.switchToTrading();
        vm.expectRevert(abi.encodeWithSelector(TradingGuard.TargetNotWhitelisted.selector, randomAddr));
        mockSafe.execThroughGuard(
            guard, randomAddr, 0, "", Enum.Operation.Call, botKey
        );
    }
}
