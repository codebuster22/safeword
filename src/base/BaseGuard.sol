// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.20;

import {IGuard} from "../interfaces/IGuard.sol";

abstract contract BaseGuard is IGuard {
    /// @dev Returns true for the Guard interface ID and ERC-165.
    /// The Guard interface ID must equal 0xe6d7a83a to be accepted by Safe's setGuard().
    function supportsInterface(bytes4 interfaceId) external pure virtual returns (bool) {
        return interfaceId == type(IGuard).interfaceId || interfaceId == 0x01ffc9a7;
    }
}
