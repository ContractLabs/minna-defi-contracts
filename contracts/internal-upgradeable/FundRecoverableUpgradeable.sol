// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {
    ContextUpgradeable
} from "oz-custom/contracts/oz-upgradeable/utils/ContextUpgradeable.sol";

import {
    IFundRecoverableUpgradeable
} from "./interfaces/IFundRecoverableUpgradeable.sol";

import {ErrorHandler} from "oz-custom/contracts/libraries/ErrorHandler.sol";

abstract contract FundRecoverableUpgradeable is
    ContextUpgradeable,
    IFundRecoverableUpgradeable
{
    using ErrorHandler for bool;

    function recover(
        RecoverCallData[] calldata calldata_,
        bytes calldata data_
    ) external virtual {
        _beforeRecover(data_);
        _recover(calldata_);
    }

    function _beforeRecover(bytes memory) internal virtual;

    function _recover(RecoverCallData[] calldata calldata_) internal virtual {
        uint256 length = calldata_.length;
        bytes[] memory results = new bytes[](length);

        bool success;
        bytes memory returnOrRevertData;
        for (uint256 i; i < length; ) {
            (success, returnOrRevertData) = calldata_[i].target.call{
                value: calldata_[i].value
            }(calldata_[i].callData);

            success.handleRevertIfNotSuccess(returnOrRevertData);

            results[i] = returnOrRevertData;

            unchecked {
                ++i;
            }
        }

        emit Executed(_msgSender(), results);
    }

    uint256[50] private __gap;
}
