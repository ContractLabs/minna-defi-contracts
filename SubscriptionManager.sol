// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {
    FundRecoverableUpgradeable
} from "./internal-upgradeable/FundRecoverableUpgradeable.sol";
import {IERC20} from "./utils/permit2/interfaces/IPermit2.sol";
import {ISubscriptionManager} from "./interfaces/ISubscriptionManager.sol";
import {
    UUPSUpgradeable
} from "oz-custom/contracts/oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    AccessControlUpgradeable
} from "oz-custom/contracts/oz-upgradeable/access/AccessControlUpgradeable.sol";

//* 0x5eec0d45
//* 00000000000000000000000047b0fb7281206373f8672fcafed0c6afc6516b32 // from
//* 000000000000000000000000d6609f7406db6a13d784b061e2fa614c7ad85844 // to ~ address(this)
//* 0000000000000000000000000000000000000000000000000000000001c9c380 // amount

contract SubscriptionManager is
    UUPSUpgradeable,
    ISubscriptionManager,
    AccessControlUpgradeable,
    FundRecoverableUpgradeable
{
    bytes32 public constant OPERATOR_ROLE =
        0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929;
    bytes32 public constant UPGRADER_ROLE =
        0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3;
    bytes32 public constant TREASURER_ROLE =
        0x3496e2e73c4d42b75d702e60d9e48102720b8691234415963a5a857b86425d07;

    FeeInfo public feeInfo;
    address public payment;

    function initialize(
        address payment_,
        uint96 amount_,
        address recipient_
    ) external initializer {
        address sender = _msgSender();
        _setPayment(sender, payment_);
        _setFeeInfo(recipient_, amount_, feeInfo);

        _grantRole(OPERATOR_ROLE, sender);

        _grantRole(OPERATOR_ROLE, recipient_);
        _grantRole(UPGRADER_ROLE, recipient_);
        _grantRole(TREASURER_ROLE, recipient_);
        _grantRole(DEFAULT_ADMIN_ROLE, recipient_);
    }

    function setPayment(address payment_) external onlyRole(TREASURER_ROLE) {
        _setPayment(_msgSender(), payment_);
    }

    function setFeeInfo(
        address recipient_,
        uint96 amount_
    ) external onlyRole(TREASURER_ROLE) {
        FeeInfo memory _feeInfo = feeInfo;

        _revokeRole(OPERATOR_ROLE, _feeInfo.recipient);
        _revokeRole(UPGRADER_ROLE, _feeInfo.recipient);
        _revokeRole(TREASURER_ROLE, _feeInfo.recipient);
        _revokeRole(DEFAULT_ADMIN_ROLE, _feeInfo.recipient);

        _setFeeInfo(recipient_, amount_, _feeInfo);

        _grantRole(OPERATOR_ROLE, recipient_);
        _grantRole(UPGRADER_ROLE, recipient_);
        _grantRole(TREASURER_ROLE, recipient_);
        _grantRole(DEFAULT_ADMIN_ROLE, recipient_);
    }

    function distributeBonuses(
        Bonus[] calldata bonuses
    )
        public
        onlyRole(TREASURER_ROLE)
        returns (uint256[] memory success, bytes[] memory results)
    {
        uint256 length = bonuses.length;
        success = new uint256[](length);
        results = new bytes[](length);

        bytes memory callData = abi.encodeCall(
            IERC20.transfer,
            (address(0), 0)
        );
        address _payment = payment;

        bool ok;
        address recipient;
        uint256 bonus;

        for (uint256 i; i < length; ) {
            bonus = bonuses[i].bonus;
            recipient = bonuses[i].recipient;
            assembly {
                mstore(add(callData, 0x24), recipient)
                mstore(add(callData, 0x44), bonus)
            }

            (ok, results[i]) = _payment.call(callData);

            success[i] = ok ? 2 : 1;

            unchecked {
                ++i;
            }
        }

        emit Distributed(_msgSender(), success, results);
    }

    function claimFees(
        address[] calldata accounts_
    )
        public
        onlyRole(OPERATOR_ROLE)
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

    function claimFees(
        Claim[] calldata claims_
    )
        external
        onlyRole(OPERATOR_ROLE)
        returns (uint256[] memory success, bytes[] memory results)
    {
        uint256 length = claims_.length;
        results = new bytes[](length);
        success = new uint256[](length);

        FeeInfo memory _feeInfo = feeInfo;

        bytes memory callData = abi.encodeCall(
            IERC20.transferFrom,
            (address(0), address(this), 0)
        );

        address _payment = payment;
        bool ok;
        address account;
        uint256 percent;
        uint256 fee;
        for (uint256 i; i < length; ) {
            account = claims_[i].from;
            percent = claims_[i].discountPercentage;
            fee = _feeInfo.amount - ((_feeInfo.amount * percent) / 10_000);
            assembly {
                mstore(add(callData, 0x24), account)
                mstore(add(callData, 0x64), fee)
            }

            (ok, results[i]) = _payment.call(callData);

            success[i] = ok ? 2 : 1;

            unchecked {
                ++i;
            }
        }

        emit Claimed(_msgSender(), success, results);
    }

    function withdraw(uint256 amount_) public onlyRole(TREASURER_ROLE) {
        FeeInfo memory _feeInfo = feeInfo;
        address _payment = payment;

        if (amount_ > IERC20(_payment).balanceOf(address(this)))
            revert SubscriptionManager__InsufficientAmount();

        IERC20(_payment).transfer(_feeInfo.recipient, amount_);
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
        _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override {}

    uint256[48] private __gap;
}