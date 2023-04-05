// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "oz-custom/contracts/oz/access/Ownable.sol";

import {FundRecoverable} from "./internal/FundRecoverable.sol";

import {IERC20} from "./utils/permit2/interfaces/IPermit2.sol";
import {ISubscriptionManager} from "./interfaces/ISubscriptionManager.sol";

contract SubscriptionManager is Ownable, FundRecoverable, ISubscriptionManager {
    FeeInfo public feeInfo;

    address public payment;

    constructor(
        address payment_,
        uint96 amount_,
        address recipient_
    ) payable Ownable() {
        _setPayment(_msgSender(), payment_);
        _setFeeInfo(recipient_, amount_, feeInfo);
    }

    function setPayment(address payment_) external onlyOwner {
        _setPayment(_msgSender(), payment_);
    }

    function setFeeInfo(address recipient_, uint96 amount_) external {
        FeeInfo memory _feeInfo = feeInfo;
        address sender = _msgSender();
        if (sender != _feeInfo.recipient)
            revert SubscriptionManager__Unauthorized(sender);

        _setFeeInfo(recipient_, amount_, _feeInfo);
    }

    function claimFees(
        address[] calldata accounts_
    )
        external
        onlyOwner
        returns (uint256[] memory success, bytes[] memory results)
    {
        uint256 length = accounts_.length;
        results = new bytes[](length);
        success = new uint256[](length);

        FeeInfo memory _feeInfo = feeInfo;

        bytes memory callData = abi.encodeCall(
            IERC20.transferFrom,
            (address(0), _feeInfo.recipient, _feeInfo.amount)
        );

        address _payment = payment;
        bool ok;
        address account;
        for (uint256 i; i < length; ) {
            account = accounts_[i];

            assembly {
                mstore(add(callData, 0x24), account)
            }

            (ok, results[i]) = _payment.call(callData);

            success[i] = ok ? 2 : 1;

            unchecked {
                ++i;
            }
        }

        emit Claimed(_msgSender(), success, results);
    }

    function _setPayment(address sender_, address payment_) internal {
        emit NewPayment(sender_, payment, payment_);
        payment = payment_;
    }

    function _setFeeInfo(
        address recipient_,
        uint96 amount_,
        FeeInfo memory currentFeeInfo_
    ) internal {
        if (recipient_ == address(0))
            revert SubscriptionManager__InvalidArgument();

        FeeInfo memory _feeInfo = FeeInfo(recipient_, amount_);
        emit NewFeeInfo(_msgSender(), currentFeeInfo_, _feeInfo);

        feeInfo = _feeInfo;
    }

    function _beforeRecover(bytes memory) internal view override {
        _checkOwner(_msgSender());
    }
}
