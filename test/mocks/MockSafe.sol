// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IGuard} from "../../src/interfaces/IGuard.sol";
import {Enum} from "../../src/interfaces/IGnosisSafe.sol";

contract MockSafe {
    function execThroughGuard(
        IGuard guard,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        address msgSender
    ) external {
        guard.checkTransaction(
            to,
            value,
            data,
            operation,
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(address(0)), // refundReceiver
            "", // signatures
            msgSender
        );
    }
}
