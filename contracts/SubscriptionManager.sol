// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "oz-custom/contracts/oz/access/Ownable.sol";

import {FundRecoverable} from "./internal/FundRecoverable.sol";

import {IERC20} from "./utils/permit2/interfaces/IPermit2.sol";
import {ISubscriptionManager} from "./interfaces/ISubscriptionManager.sol";

contract SubscriptionManager is Ownable, FundRecoverable, ISubscriptionManager {
    uint256 public constant PERCENTAGE_FRACTION = 10_000;
    FeeInfo public feeInfo;
    uint96 public commissionFee;
    address public payment;

    constructor(
        address payment_,
        uint96 amount_,
        address recipient_,
        uint96 commissionFee_
    ) payable Ownable() {
        _setPayment(_msgSender(), payment_);
        _setFeeInfo(recipient_, amount_, feeInfo);
        _setCommissionFee(recipient_, commissionFee_);
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

    function setCommissionFee(uint96 feeFraction_) external {
        FeeInfo memory _feeInfo = feeInfo;
        address sender = _msgSender();
        if (sender != _feeInfo.recipient)
            revert SubscriptionManager__Unauthorized(sender);

        _setCommissionFee(sender, feeFraction_);
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
            (address(0), address(this), _feeInfo.amount)
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

    function distributeCash(
        Affiliate[] calldata affiliates_
    ) external onlyOwner {
        uint256 length = affiliates_.length;

        FeeInfo memory _feeInfo = feeInfo;
        Affiliate memory affiliate;
        address _payment = payment;
        uint256 commission = (_feeInfo.amount * commissionFee) /
            PERCENTAGE_FRACTION;
        uint256 totalCommision;
        for (uint256 i; i < length; ) {
            affiliate = affiliates_[i];
            totalCommision = affiliate.refferedAmount * commission;
            IERC20(_payment).transferFrom(
                address(this),
                affiliate.account,
                totalCommision
            );

            unchecked {
                ++i;
            }
        }
        uint256 _balance = IERC20(_payment).balanceOf(address(this));
        IERC20(_payment).transferFrom(
            address(this),
            _feeInfo.recipient,
            _balance
        );
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

    function _setCommissionFee(
        address recipient,
        uint96 feeFraction_
    ) internal {
        emit CommissionFeeUpdated(recipient, commissionFee, feeFraction_);
        commissionFee = feeFraction_;
    }

    function _beforeRecover(bytes memory) internal view override {
        _checkOwner(_msgSender());
    }
}
