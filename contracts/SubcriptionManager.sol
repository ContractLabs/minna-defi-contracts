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

    uint256 private storageChainId;
    FeeInfo public feeInfo;
    EnumerableSet.AddressSet private __supportedTokens;
    mapping(address => Subscriber[]) private __subscribers;

    constructor(address owner_) Ownable() {
        _transferOwnership(owner_);
    }

    function setWhichChainUseStorage(uint256 chainId_) external onlyOwner {
        storageChainId = chainId_;
    }

    function setFeeInfo(address recipient_, uint96 amount_) external onlyOwner {
        emit NewFeeInfo(owner(), feeInfo, FeeInfo(recipient_, amount_));

        feeInfo.recipient = recipient_;
        feeInfo.amount = amount_;
    }

    function setFeeTokens(FeeToken[] calldata feeTokens_) external onlyOwner {
        uint256 length = feeTokens_.length;
        for (uint256 i; i < length; ) {
            feeTokens_[i].isSet
                ? __supportedTokens.add(feeTokens_[i].token)
                : __supportedTokens.remove(feeTokens_[i].token);

            unchecked {
                ++i;
            }
        }

        emit FeeTokensUpdated(owner(), feeTokens_);
    }

    function subscribe(
        address token_,
        address account_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {
        if (token_ != address(0))
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

        if (getChainId() == storageChainId) {
            Subscriber memory subscriber = Subscriber(account_, false);
            __subscribers[token_].push(subscriber);
        }
    }

    function claimFees(address paymentToken_) external onlyOwner {
        uint256 length = __subscribers[paymentToken_].length;
        bool[] memory successArr;
        bytes[] memory result;
        for (uint256 i; i < length; ) {
            (bool success, bytes memory data) = paymentToken_.call(
                abi.encodeWithSignature(
                    "transferFrom(address, address, uint256)",
                    __subscribers[paymentToken_][i].account,
                    owner(),
                    feeInfo.amount
                )
            );
            // IERC20(paymentToken_).transferFrom(
            //     __subscribers[paymentToken_][i].account,
            //     owner(),
            //     feeInfo.amount
            // );
            successArr[i] = success;
            result[i] = data;

            unchecked {
                ++i;
            }
        }

        emit Claimed(owner(), successArr, result);
    }

    function claimFees(ClaimInfo[] calldata claimInfo_) external onlyOwner {
        uint256 length = claimInfo_.length;
        bool[] memory successArr;
        bytes[] memory result;
        for (uint256 i; i < length; ) {
            (bool success, bytes memory data) = claimInfo_[i].token.call(
                abi.encodeWithSignature(
                    "transferFrom(address, address, uint256)",
                    claimInfo_[i].account,
                    owner(),
                    feeInfo.amount
                )
            );
            // IERC20(claimInfo_[i].token).transferFrom(
            //     claimInfo_[i].account,
            //     owner(),
            //     feeInfo.amount
            // );
            successArr[i] = success;
            result[i] = data;

            unchecked {
                ++i;
            }
        }

        emit Claimed(owner(), successArr, result);
    }

    function getChainId() private view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }

    function viewSubscribers(
        address paymentToken_
    ) external view returns (Subscriber[] memory) {
        return __subscribers[paymentToken_];
    }

    function viewSupportedTokens() external view returns (address[] memory) {
        return __supportedTokens.values();
    }
}
