// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TradingGuard} from "../src/TradingGuard.sol";
import {GuardFactory} from "../src/GuardFactory.sol";
import {IGnosisSafe, Enum} from "../src/interfaces/IGnosisSafe.sol";

contract TradingGuardForkTest is Test {
    // --- Constants ---
    uint256 constant TEST_PK = 0xBEEF;
    // Note: no pinned block — public RPCs don't serve archive state.
    // For deterministic tests, use an archive RPC and uncomment a pinned block.

    address constant SAFE_ADDR = 0x998679089cDc7A9a116937C720517C95dB6DBA75;
    address constant CTF_EXCHANGE = 0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E;
    address constant NEG_RISK_CTF_EXCHANGE = 0xC5d563A36AE78145C45a50134d48A1215220f80a;
    address constant NEG_RISK_ADAPTER = 0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296;

    bytes32 constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

    // --- State ---
    IGnosisSafe public safe;
    TradingGuard public guard;
    GuardFactory public factory;
    address public testOwner;

    // --- setUp ---
    function setUp() public {
        // 1. Fork Polygon
        vm.createSelectFork(vm.envString("POLYGON_RPC_URL"));

        safe = IGnosisSafe(SAFE_ADDR);
        testOwner = vm.addr(TEST_PK);

        // 2. Add testOwner as Safe owner (test setup, not flow under test)
        vm.prank(SAFE_ADDR);
        safe.addOwnerWithThreshold(testOwner, 1);

        // 3. Deploy GuardFactory + TradingGuard with testOwner as admin
        address[] memory whitelist = new address[](3);
        whitelist[0] = CTF_EXCHANGE;
        whitelist[1] = NEG_RISK_CTF_EXCHANGE;
        whitelist[2] = NEG_RISK_ADAPTER;

        factory = new GuardFactory();
        address guardAddr = factory.deploy(testOwner, whitelist);
        guard = TradingGuard(guardAddr);

        // 4. Set guard on Safe via execTransaction (guard not active yet during this call)
        bytes memory setGuardData = abi.encodeWithSelector(IGnosisSafe.setGuard.selector, guardAddr);
        this.execOnSafe(SAFE_ADDR, 0, setGuardData, Enum.Operation.Call);
    }

    // --- Helpers (public so vm.expectRevert can wrap the entire call via this.execOnSafe) ---
    function execOnSafe(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation op
    ) public returns (bool) {
        uint256 nonce = safe.nonce();
        bytes32 txHash = safe.getTransactionHash(
            to, value, data, op,
            100000, // safeTxGas — non-zero so inner call failure returns false instead of reverting
            0, 0, address(0), address(0), nonce
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TEST_PK, txHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        return safe.execTransaction(
            to, value, data, op,
            100000, 0, 0, address(0), payable(address(0)), sig
        );
    }

    function execOnSafeAsOwner(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation op
    ) public returns (bool) {
        uint256 nonce = safe.nonce();
        bytes32 txHash = safe.getTransactionHash(
            to, value, data, op,
            100000, 0, 0, address(0), address(0), nonce
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TEST_PK, txHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        vm.prank(testOwner);
        return safe.execTransaction(
            to, value, data, op,
            100000, 0, 0, address(0), payable(address(0)), sig
        );
    }

    // ═══════════════════════════════════════════════════
    // Setup Verification
    // ═══════════════════════════════════════════════════

    function test_fork_safeSetupCorrect() public view {
        assertTrue(safe.isOwner(testOwner));
        assertEq(safe.getThreshold(), 1);
        bytes32 guardSlot = vm.load(SAFE_ADDR, GUARD_STORAGE_SLOT);
        assertEq(guardSlot, bytes32(uint256(uint160(address(guard)))));
    }

    function test_fork_guardState() public view {
        assertEq(guard.owner(), testOwner);
        assertTrue(guard.whitelisted(CTF_EXCHANGE));
        assertTrue(guard.whitelisted(NEG_RISK_CTF_EXCHANGE));
        assertTrue(guard.whitelisted(NEG_RISK_ADAPTER));
        assertEq(uint8(guard.mode()), uint8(TradingGuard.Mode.Trading));
    }

    // ═══════════════════════════════════════════════════
    // Trading Mode — Guard Enforcement
    // ═══════════════════════════════════════════════════

    function test_fork_whitelistedCallAllowed() public {
        this.execOnSafe(CTF_EXCHANGE, 0, "", Enum.Operation.Call);
    }

    function test_fork_nonWhitelistedCallBlocked() public {
        address random = makeAddr("random");
        vm.expectRevert(abi.encodeWithSelector(TradingGuard.TargetNotWhitelisted.selector, random));
        this.execOnSafe(random, 0, "", Enum.Operation.Call);
    }

    function test_fork_delegatecallBlocked() public {
        vm.expectRevert(TradingGuard.DelegatecallBlocked.selector);
        this.execOnSafe(CTF_EXCHANGE, 0, "", Enum.Operation.DelegateCall);
    }

    function test_fork_selfCallBlocked() public {
        vm.expectRevert(TradingGuard.SelfCallBlocked.selector);
        this.execOnSafe(SAFE_ADDR, 0, "", Enum.Operation.Call);
    }

    // ═══════════════════════════════════════════════════
    // Unlocked Mode
    // ═══════════════════════════════════════════════════

    function test_fork_unlockedAllowsNonWhitelisted() public {
        vm.prank(testOwner);
        guard.switchToUnlocked();

        address random = makeAddr("random");
        this.execOnSafe(random, 0, "", Enum.Operation.Call);
    }

    function test_fork_unlockedAllowsSelfCall() public {
        vm.prank(testOwner);
        guard.switchToUnlocked();

        this.execOnSafe(SAFE_ADDR, 0, "", Enum.Operation.Call);
    }

    // ═══════════════════════════════════════════════════
    // FailSafe Mode
    // ═══════════════════════════════════════════════════

    function test_fork_failSafeBlocksWhitelisted() public {
        vm.prank(testOwner);
        guard.switchToFailSafe();

        vm.expectRevert(TradingGuard.FailSafeActive.selector);
        this.execOnSafe(CTF_EXCHANGE, 0, "", Enum.Operation.Call);
    }

    // ═══════════════════════════════════════════════════
    // Full Mode Transition Flow
    // ═══════════════════════════════════════════════════

    function test_fork_fullModeTransitionFlow() public {
        address random = makeAddr("random");

        // Trading mode — non-whitelisted blocked
        vm.expectRevert(abi.encodeWithSelector(TradingGuard.TargetNotWhitelisted.selector, random));
        this.execOnSafe(random, 0, "", Enum.Operation.Call);

        // Switch to Unlocked — non-whitelisted allowed
        vm.prank(testOwner);
        guard.switchToUnlocked();
        this.execOnSafe(random, 0, "", Enum.Operation.Call);

        // Switch back to Trading — non-whitelisted blocked again
        vm.prank(testOwner);
        guard.switchToTrading();
        vm.expectRevert(abi.encodeWithSelector(TradingGuard.TargetNotWhitelisted.selector, random));
        this.execOnSafe(random, 0, "", Enum.Operation.Call);

        // Switch to FailSafe — even whitelisted blocked
        vm.prank(testOwner);
        guard.switchToFailSafe();
        vm.expectRevert(TradingGuard.FailSafeActive.selector);
        this.execOnSafe(CTF_EXCHANGE, 0, "", Enum.Operation.Call);

        // Switch back to Trading — whitelisted works again
        vm.prank(testOwner);
        guard.switchToTrading();
        this.execOnSafe(CTF_EXCHANGE, 0, "", Enum.Operation.Call);
    }

    // ═══════════════════════════════════════════════════
    // Security Fixes
    // ═══════════════════════════════════════════════════

    function test_fork_failSafeAllowsAdmin() public {
        vm.prank(testOwner);
        guard.switchToFailSafe();
        this.execOnSafeAsOwner(CTF_EXCHANGE, 0, "", Enum.Operation.Call);
    }

    function test_fork_tradingBlocksGasRefund() public {
        uint256 nonce = safe.nonce();
        bytes32 txHash = safe.getTransactionHash(
            CTF_EXCHANGE, 0, "", Enum.Operation.Call,
            100000, 0, 1, address(0), address(0), nonce
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TEST_PK, txHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        vm.expectRevert(TradingGuard.GasRefundNotAllowed.selector);
        safe.execTransaction(
            CTF_EXCHANGE, 0, "", Enum.Operation.Call,
            100000, 0, 1, address(0), payable(address(0)), sig
        );
    }
}
