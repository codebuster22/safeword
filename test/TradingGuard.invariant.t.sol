// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TradingGuard} from "../src/TradingGuard.sol";
import {IGuard} from "../src/interfaces/IGuard.sol";
import {Enum} from "../src/interfaces/IGnosisSafe.sol";
import {MockSafe} from "./mocks/MockSafe.sol";

/// @notice Handler contract — the only target the fuzzer calls.
contract TradingGuardHandler is Test {
    TradingGuard public guard;
    MockSafe public mockSafe;
    address public owner;

    // Ghost state
    TradingGuard.Mode public currentMode;
    uint256 public modeChanges;
    uint256 public callCount;

    constructor(TradingGuard _guard, MockSafe _mockSafe, address _owner) {
        guard = _guard;
        mockSafe = _mockSafe;
        owner = _owner;
        currentMode = TradingGuard.Mode.Trading;
    }

    function switchToTrading() external {
        vm.prank(owner);
        guard.switchToTrading();
        currentMode = TradingGuard.Mode.Trading;
        modeChanges++;
    }

    function switchToUnlocked() external {
        vm.prank(owner);
        guard.switchToUnlocked();
        currentMode = TradingGuard.Mode.Unlocked;
        modeChanges++;
    }

    function switchToFailSafe() external {
        vm.prank(owner);
        guard.switchToFailSafe();
        currentMode = TradingGuard.Mode.FailSafe;
        modeChanges++;
    }

    function addToWhitelist(uint256 seed) external {
        address target = address(uint160(bound(seed, 1, type(uint160).max)));
        vm.prank(owner);
        guard.setWhitelisted(target, true);
    }

    function removeFromWhitelist(uint256 seed) external {
        address target = address(uint160(bound(seed, 1, type(uint160).max)));
        vm.prank(owner);
        guard.setWhitelisted(target, false);
    }

    function execTransaction(uint256 targetSeed, bool isDelegatecall) external {
        address target = address(uint160(bound(targetSeed, 1, type(uint160).max)));
        Enum.Operation op = isDelegatecall ? Enum.Operation.DelegateCall : Enum.Operation.Call;
        callCount++;

        try mockSafe.execThroughGuard(IGuard(address(guard)), target, 0, "", op, address(mockSafe)) {
            // allowed
        } catch {
            // blocked
        }
    }
}

/// @notice Invariant test suite for TradingGuard.
contract TradingGuardInvariantTest is Test {
    TradingGuard public guard;
    MockSafe public mockSafe;
    TradingGuardHandler public handler;

    address public owner = makeAddr("owner");
    address public whitelistedTarget = makeAddr("whitelistedTarget");

    function setUp() public {
        address[] memory whitelist = new address[](1);
        whitelist[0] = whitelistedTarget;

        guard = new TradingGuard(owner, whitelist);
        mockSafe = new MockSafe();
        handler = new TradingGuardHandler(guard, mockSafe, owner);

        targetContract(address(handler));
    }

    // --- Invariants ---

    function invariant_modeMatchesGhost() external view {
        assertEq(uint8(guard.mode()), uint8(handler.currentMode()));
    }

    function invariant_failSafeBlocksAll() external {
        if (guard.mode() != TradingGuard.Mode.FailSafe) return;

        vm.expectRevert(TradingGuard.FailSafeActive.selector);
        mockSafe.execThroughGuard(
            IGuard(address(guard)), address(0x1234), 0, "", Enum.Operation.Call, address(mockSafe)
        );
    }

    function invariant_unlockedAllowsAll() external {
        if (guard.mode() != TradingGuard.Mode.Unlocked) return;

        // Any target, any operation should pass
        mockSafe.execThroughGuard(
            IGuard(address(guard)), address(0x1234), 0, "", Enum.Operation.Call, address(mockSafe)
        );
        mockSafe.execThroughGuard(
            IGuard(address(guard)), address(0x5678), 0, "", Enum.Operation.DelegateCall, address(mockSafe)
        );
    }

    function invariant_tradingBlocksDelegatecall() external {
        if (guard.mode() != TradingGuard.Mode.Trading) return;

        vm.expectRevert(TradingGuard.DelegatecallBlocked.selector);
        mockSafe.execThroughGuard(
            IGuard(address(guard)), address(0x1234), 0, "", Enum.Operation.DelegateCall, address(mockSafe)
        );
    }

    function invariant_tradingBlocksSelfCall() external {
        if (guard.mode() != TradingGuard.Mode.Trading) return;

        vm.expectRevert(TradingGuard.SelfCallBlocked.selector);
        mockSafe.execThroughGuard(
            IGuard(address(guard)), address(mockSafe), 0, "", Enum.Operation.Call, address(mockSafe)
        );
    }

    function invariant_tradingBlocksNonWhitelisted() external {
        if (guard.mode() != TradingGuard.Mode.Trading) return;

        address random = address(0xDEAD);
        if (guard.whitelisted(random)) return;

        vm.expectRevert(abi.encodeWithSelector(TradingGuard.TargetNotWhitelisted.selector, random));
        mockSafe.execThroughGuard(
            IGuard(address(guard)), random, 0, "", Enum.Operation.Call, address(mockSafe)
        );
    }
}
