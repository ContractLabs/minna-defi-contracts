// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {
    EnumerableSet
} from "oz-custom/contracts/oz/utils/structs/EnumerableSet.sol";
import {Ownable} from "oz-custom/contracts/oz/access/Ownable.sol";
import {
    IERC20,
    IERC20Permit
} from "oz-custom/contracts/oz/token/ERC20/extensions/IERC20Permit.sol";
import {ISubscriptionManager} from "./interfaces/ISubscriptionManager.sol";

contract SubscriptionManager is ISubscriptionManager, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    FeeInfo public feeInfo;
    uint256 private __useStorage = 2;

    EnumerableSet.AddressSet private __supportedTokens;
    mapping(address => Subscriber[]) private __subscribers;

    constructor(
        uint96 amount_,
        bool useStorage_,
        address recipient_
    ) payable Ownable() {
        _setFeeInfo(recipient_, amount_);
        if (useStorage_) _toggleUseStorage();
    }

    function _toggleUseStorage() internal {
        emit ToggleUseStorage(_msgSender(), !isUseStorage());
        __useStorage ^= 1;
    }

    function toggleUseStorage() external onlyOwner {
        _toggleUseStorage();
    }

    function setFeeInfo(address recipient_, uint96 amount_) external onlyOwner {
        _setFeeInfo(recipient_, amount_);
    }

    function _setFeeInfo(address recipient_, uint96 amount_) internal {
        FeeInfo memory _feeInfo = FeeInfo(recipient_, amount_);
        emit NewFeeInfo(_msgSender(), feeInfo, _feeInfo);

        feeInfo = _feeInfo;
    }

    function setFeeTokens(FeeToken[] calldata feeTokens_) external onlyOwner {
        uint256 length = feeTokens_.length;

        FeeToken memory feeToken;
        for (uint256 i; i < length; ) {
            feeToken = feeTokens_[i];
            feeToken.isSet
                ? __supportedTokens.add(feeToken.token)
                : __supportedTokens.remove(feeToken.token);

            unchecked {
                ++i;
            }
        }

        emit FeeTokensUpdated(_msgSender(), feeTokens_);
    }

    function subscribe(
        address token_,
        address account_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {
        if (!__supportedTokens.contains(token_))
            revert SubscriptionManager__UnsupportedToken(token_);

        IERC20Permit(token_).permit(
            account_,
            address(this),
            feeInfo.amount,
            deadline_,
            v_,
            r_,
            s_
        );

        if (isUseStorage())
            __subscribers[token_].push(Subscriber(account_, false));
    }

    function claimFees(address paymentToken_) external onlyOwner {
        if (!isUseStorage()) revert SubscriptionManager__InvalidChain();

        uint256 length = __subscribers[paymentToken_].length;
        bool[] memory success = new bool[](length);
        bytes[] memory results = new bytes[](length);

        FeeInfo memory _feeInfo = feeInfo;
        for (uint256 i; i < length; ) {
            (success[i], results[i]) = paymentToken_.call(
                abi.encodeCall(
                    IERC20.transferFrom,
                    (
                        __subscribers[paymentToken_][i].account,
                        _feeInfo.recipient,
                        _feeInfo.amount
                    )
                )
            );

            // blacklist user if call failed
            if (!success[i])
                __subscribers[paymentToken_][i].isBlacklisted = true;

            unchecked {
                ++i;
            }
        }

        emit Claimed(_msgSender(), success, results);
    }

    function claimFees(ClaimInfo[] calldata claimInfo_) external onlyOwner {
        if (isUseStorage()) revert SubscriptionManager__InvalidChain();

        uint256 length = claimInfo_.length;
        bool[] memory success = new bool[](length);
        bytes[] memory results = new bytes[](length);

        FeeInfo memory _feeInfo = feeInfo;
        for (uint256 i; i < length; ) {
            (success[i], results[i]) = claimInfo_[i].token.call(
                abi.encodeCall(
                    IERC20.transferFrom,
                    (claimInfo_[i].account, _feeInfo.recipient, _feeInfo.amount)
                )
            );

            unchecked {
                ++i;
            }
        }

        emit Claimed(_msgSender(), success, results);
    }

    function viewSubscribers(
        address paymentToken_
    ) external view returns (Subscriber[] memory) {
        return __subscribers[paymentToken_];
    }

    function viewSupportedTokens() external view returns (address[] memory) {
        return __supportedTokens.values();
    }

    function isUseStorage() public view returns (bool) {
        return __useStorage == 3;
    }
}
