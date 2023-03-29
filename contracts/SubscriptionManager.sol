// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {
    EnumerableSet
} from "oz-custom/contracts/oz/utils/structs/EnumerableSet.sol";
import {Ownable} from "oz-custom/contracts/oz/access/Ownable.sol";

import {ErrorHandler, FundRecoverable} from "./internal/FundRecoverable.sol";

import {
    IERC20Permit
} from "oz-custom/contracts/oz/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20, IPermit2} from "./utils/permit2/interfaces/IPermit2.sol";
import {ISubscriptionManager} from "./interfaces/ISubscriptionManager.sol";

import {
    FixedPointMathLib
} from "oz-custom/contracts/libraries/FixedPointMathLib.sol";
import {SigUtil} from "oz-custom/contracts/libraries/SigUtil.sol";

contract SubscriptionManager is Ownable, FundRecoverable, ISubscriptionManager {
    using SigUtil for bytes;
    using EnumerableSet for *;
    using ErrorHandler for bool;
    using FixedPointMathLib for uint256;

    FeeInfo public feeInfo;
    IPermit2 public permit2;

    uint256 private __useStorage;

    mapping(address => bool) private __isUsePermit2;

    EnumerableSet.AddressSet private __supportedTokens;

    mapping(address => EnumerableSet.AddressSet) private __subscribers;

    mapping(address => SubscriptionStatus) private __subscriptionStatuses;

    modifier whenUseStorage() {
        _checkUseStorage();
        _;
    }

    constructor(
        uint96 amount_,
        bool useStorage_,
        IPermit2 permit2_,
        address recipient_
    ) payable Ownable() {
        __useStorage = 2;
        _setPermit2(permit2_);
        if (useStorage_) _toggleUseStorage();
        _setFeeInfo(recipient_, amount_, feeInfo);
    }

    function setPermit2(IPermit2 permit2_) external onlyOwner {
        _setPermit2(permit2_);
    }

    function toggleUseStorage() external onlyOwner {
        _toggleUseStorage();
    }

    function setFeeInfo(address recipient_, uint96 amount_) external {
        FeeInfo memory _feeInfo = feeInfo;
        address sender = _msgSender();
        if (sender != _feeInfo.recipient)
            revert SubscriptionManager__Unauthorized(sender);

        _setFeeInfo(recipient_, amount_, _feeInfo);
    }

    function setFeeTokens(FeeToken[] calldata feeTokens_) external onlyOwner {
        uint256 length = feeTokens_.length;

        FeeToken memory feeToken;
        address token;
        for (uint256 i; i < length; ) {
            feeToken = feeTokens_[i];
            token = feeToken.token;

            feeToken.isSet
                ? __supportedTokens.add(token)
                : __supportedTokens.remove(token);

            if (feeToken.usePermit2) __isUsePermit2[token] = true;

            unchecked {
                ++i;
            }
        }

        emit FeeTokensUpdated(_msgSender(), feeTokens_);
    }

    function subscribe(
        address account_,
        uint64 duration_,
        Payment calldata payment_
    ) external {
        address token = payment_.token;
        if (!__supportedTokens.contains(token))
            revert SubscriptionManager__UnsupportedToken(token);

        if (isUseStorage()) {
            __subscribers[token].add(account_);
            __subscriptionStatuses[account_].expiry = uint64(
                duration_ + block.timestamp
            );
        }

        FeeInfo memory _feeInfo = feeInfo;

        uint256 feeAmount = uint256(_feeInfo.amount).mulDivDown(
            duration_,
            viewSubscriptionDuration()
        );

        if (payment_.amount < feeAmount)
            revert SubscriptionManager__InsufficientBalance();

        IPermit2 _permit2 = permit2;
        (uint256 allowance, bool usePermit2) = _viewSelfAllowance(
            _permit2,
            token,
            account_
        );
        if (allowance < feeAmount) {
            if (usePermit2) {
                _permit2.permit({
                    owner: account_,
                    permitSingle: IPermit2.PermitSingle({
                        details: IPermit2.PermitDetails({
                            token: token,
                            amount: payment_.amount,
                            expiration: payment_.approvalExpiration,
                            nonce: payment_.nonce
                        }),
                        spender: address(this),
                        sigDeadline: payment_.deadline
                    }),
                    signature: payment_.signature
                });
            } else {
                (bytes32 r, bytes32 s, uint8 v) = payment_.signature.split();

                IERC20Permit(token).permit(
                    account_,
                    address(this),
                    payment_.amount,
                    payment_.deadline,
                    v,
                    r,
                    s
                );
            }
        }

        (bool ok, bytes memory returnOrRevertData) = _safeTransferFrom(
            usePermit2,
            address(_permit2),
            token,
            account_,
            _feeInfo.recipient,
            uint160(feeAmount)
        );
        ok.handleRevertIfNotSuccess(returnOrRevertData);

        emit Subscribed(_msgSender(), account_, feeAmount, duration_);
    }

    function claimFees(
        address paymentToken_
    ) external whenUseStorage onlyOwner {
        EnumerableSet.AddressSet storage subscribers = __subscribers[
            paymentToken_
        ];

        uint256 length = subscribers.length();
        bool[] memory success = new bool[](length);
        bytes[] memory results = new bytes[](length);
        address[] memory blacklisted = new address[](length);

        uint256 blacklistCount;
        address subscriber;
        IPermit2 _permit2 = permit2;
        FeeInfo memory _feeInfo = feeInfo;
        for (uint256 i; i < length; ) {
            subscriber = subscribers.at(i);

            //  @dev skip fee charging
            if (__subscriptionStatuses[subscriber].expiry < block.timestamp)
                continue;

            (success[i], results[i]) = _safeTransferFrom(
                __isUsePermit2[paymentToken_],
                address(_permit2),
                paymentToken_,
                subscriber,
                _feeInfo.recipient,
                _feeInfo.amount
            );

            unchecked {
                // blacklist user if call failed
                if (!success[i]) {
                    subscribers.remove(subscriber);
                    blacklisted[blacklistCount] = subscriber;
                    ++blacklistCount;
                }
                ++i;
            }
        }

        //  @dev shorten dynamic blacklisted array
        assembly {
            mstore(blacklisted, blacklistCount)
        }

        address sender = _msgSender();
        emit Claimed(sender, success, results);
        if (blacklistCount != 0) emit Blacklisted(sender, blacklisted);
    }

    function claimFees(ClaimInfo[] calldata claimInfo_) external onlyOwner {
        if (isUseStorage()) revert SubscriptionManager__InvalidChain();

        uint256 length = claimInfo_.length;
        bool[] memory success = new bool[](length);
        bytes[] memory results = new bytes[](length);

        ClaimInfo memory claimInfo;
        IPermit2 _permit2 = permit2;
        FeeInfo memory _feeInfo = feeInfo;
        for (uint256 i; i < length; ) {
            claimInfo = claimInfo_[i];
            (success[i], results[i]) = _safeTransferFrom(
                claimInfo.usePermit2,
                address(_permit2),
                claimInfo.token,
                claimInfo.account,
                _feeInfo.recipient,
                _feeInfo.amount
            );

            unchecked {
                ++i;
            }
        }

        emit Claimed(_msgSender(), success, results);
    }

    function viewSubscribers(
        address paymentToken_
    ) public view whenUseStorage returns (address[] memory subscribers) {
        subscribers = __subscribers[paymentToken_].values();
    }

    function viewSubscriptionStatuses(
        address[] memory subscribers_
    )
        public
        view
        whenUseStorage
        returns (SubscriptionStatus[] memory statuses)
    {
        uint256 length = subscribers_.length;
        for (uint256 i; i < length; ) {
            statuses[i] = __subscriptionStatuses[subscribers_[i]];
            unchecked {
                ++i;
            }
        }
    }

    function viewClaimableAllowance(
        address token_
    )
        external
        view
        whenUseStorage
        returns (address[] memory accounts, uint256[] memory allowances)
    {
        accounts = viewSubscribers(token_);
        uint256 length = accounts.length;
        allowances = new uint256[](length);
        IPermit2 _permit2 = permit2;
        for (uint256 i; i < length; ) {
            (allowances[i], ) = _viewSelfAllowance(
                _permit2,
                token_,
                accounts[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    function viewSubscriptionDuration() public pure returns (uint256) {
        return 4 weeks;
    }

    function viewSupportedTokens() external view returns (address[] memory) {
        return __supportedTokens.values();
    }

    function isUseStorage() public view returns (bool) {
        return __useStorage == 3;
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

    function _safeTransferFrom(
        bool usePermit2_,
        address permit2_,
        address token_,
        address from_,
        address to_,
        uint160 amount_
    ) internal returns (bool success, bytes memory returnOrRevertData) {
        if (usePermit2_)
            (success, returnOrRevertData) = permit2_.call(
                abi.encodeCall(
                    IPermit2.transferFrom,
                    (from_, to_, amount_, token_)
                )
            );
        else
            (success, returnOrRevertData) = token_.call(
                abi.encodeCall(IERC20.transferFrom, (from_, to_, amount_))
            );
    }

    function _setPermit2(IPermit2 permit2_) internal {
        emit Permit2Changed(_msgSender(), permit2, permit2_);
        permit2 = permit2_;
    }

    function _toggleUseStorage() internal {
        emit ToggleUseStorage(_msgSender(), !isUseStorage());
        __useStorage ^= 1;
    }

    function _beforeRecover(bytes memory) internal view override {
        _checkOwner(_msgSender());
    }

    function _checkUseStorage() internal view {
        if (!isUseStorage()) revert SubscriptionManager__InvalidChain();
    }

    function _viewSelfAllowance(
        IPermit2 permit2_,
        address token_,
        address owner_
    ) internal view returns (uint256 allowed, bool usePermit2) {
        if (__isUsePermit2[token_]) {
            usePermit2 = true;

            uint256 expiration;
            (allowed, expiration, ) = permit2_.allowance(
                owner_,
                token_,
                address(this)
            );
            allowed = expiration < block.timestamp ? 0 : allowed;
        } else allowed = IERC20(token_).allowance(owner_, address(this));
    }
}
