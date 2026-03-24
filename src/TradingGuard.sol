// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseGuard} from "./base/BaseGuard.sol";
import {Enum} from "./interfaces/IGnosisSafe.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TradingGuard is BaseGuard, Ownable {
    // --- Types ---
    enum Mode {
        Trading,
        Unlocked,
        FailSafe
    }

    // --- Errors ---
    error DelegatecallBlocked();
    error SelfCallBlocked();
    error TargetNotWhitelisted(address target);
    error FailSafeActive();
    error GasRefundNotAllowed();

    // --- Events ---
    event ModeChanged(Mode indexed previousMode, Mode indexed newMode);
    event WhitelistUpdated(address indexed target, bool status);

    // --- State ---
    Mode public mode;
    mapping(address => bool) public whitelisted;

    // --- Constructor ---
    /// @param _initialOwner Admin address that controls mode switching and whitelist.
    ///        Must be an EOA (hardware wallet recommended), NOT the Safe address.
    ///        Setting owner to the Safe itself will permanently brick the guard
    ///        because the Safe cannot call onlyOwner functions through the guard in Trading mode.
    constructor(address _initialOwner, address[] memory _initialWhitelist) Ownable(_initialOwner) {
        mode = Mode.Trading;
        for (uint256 i = 0; i < _initialWhitelist.length; i++) {
            whitelisted[_initialWhitelist[i]] = true;
            emit WhitelistUpdated(_initialWhitelist[i], true);
        }
    }

    // --- Guard Interface ---
    function checkTransaction(
        address to,
        uint256,
        bytes memory,
        Enum.Operation operation,
        uint256,
        uint256,
        uint256 gasPrice,
        address,
        address payable,
        bytes memory,
        address msgSender
    ) external override {
        // FailSafe mode — admin-only lockdown
        if (mode == Mode.FailSafe) {
            if (msgSender != owner()) revert FailSafeActive();
            return;
        }

        // Unlocked mode — allow all transactions
        if (mode == Mode.Unlocked) return;

        // Trading mode — enforce all restrictions
        if (operation == Enum.Operation.DelegateCall) revert DelegatecallBlocked();
        if (to == msg.sender) revert SelfCallBlocked();
        if (!whitelisted[to]) revert TargetNotWhitelisted(to);
        if (gasPrice != 0) revert GasRefundNotAllowed();
    }

    function checkAfterExecution(bytes32, bool) external override {}

    // --- Owner Functions ---
    function switchToTrading() external onlyOwner {
        Mode previousMode = mode;
        mode = Mode.Trading;
        emit ModeChanged(previousMode, Mode.Trading);
    }

    function switchToUnlocked() external onlyOwner {
        Mode previousMode = mode;
        mode = Mode.Unlocked;
        emit ModeChanged(previousMode, Mode.Unlocked);
    }

    function switchToFailSafe() external onlyOwner {
        Mode previousMode = mode;
        mode = Mode.FailSafe;
        emit ModeChanged(previousMode, Mode.FailSafe);
    }

    function setWhitelisted(address target, bool status) external onlyOwner {
        whitelisted[target] = status;
        emit WhitelistUpdated(target, status);
    }
}
