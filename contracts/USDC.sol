// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {PMT} from "oz-custom/contracts/presets/token/PMT.sol";

contract USDC is PMT {
    constructor() PMT("Coinbase USD", "USDC") {
        _mint(_msgSender(), 100_000_000 ether);
    }
}
