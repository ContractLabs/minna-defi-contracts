// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IPermit2} from "../utils/permit2/interfaces/IPermit2.sol";

interface ISubscriptionManager {
    error SubscriptionManager__InvalidChain();
    error SubscriptionManager__InvalidArgument();
    error SubscriptionManager__InsufficientBalance();
    error SubscriptionManager__Unauthorized(address caller);
    error SubscriptionManager__UnsupportedToken(address token);

    struct Payment {
        address token;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
        uint256 approvalExpiration;
        bytes signature;
    }

    struct FeeToken {
        address token;
        bool isSet;
        bool usePermit2;
    }

    struct FeeInfo {
        address recipient;
        uint96 amount;
    }

    struct ClaimInfo {
        bool usePermit2;
        address token;
        address account;
    }

    struct SubscriptionStatus {
        uint64 expiry;
        bool isBlacklisted;
    }

    event Permit2Changed(
        address indexed operator,
        IPermit2 indexed from,
        IPermit2 indexed to
    );

    event Blacklisted(address indexed operator, address[] blacklisted);

    event ToggleUseStorage(address indexed operator, bool indexed isUsed);

    event Claimed(address indexed operator, bool[] success, bytes[] results);

    event NewFeeInfo(
        address indexed operator,
        FeeInfo indexed oldFeeInfo,
        FeeInfo indexed newFeeInfo
    );

    event Subscribed(
        address indexed operator,
        address indexed account,
        uint256 indexed payout,
        uint256 duration
    );

    event FeeTokensUpdated(address indexed operator, FeeToken[] feeTokens);

    function toggleUseStorage() external;

    function setFeeInfo(address recipient_, uint96 amount_) external;

    function setFeeTokens(FeeToken[] calldata feeTokens_) external;

    function subscribe(
        address account_,
        uint64 duration_,
        Payment calldata payment_
    ) external;

    function claimFees(address paymentToken_) external;

    function claimFees(ClaimInfo[] calldata claimInfo_) external;

    function viewClaimableAllowance(
        address token_
    )
        external
        view
        returns (address[] memory account, uint256[] memory allowances);

    function viewSubscriptionStatuses(
        address[] memory subscribers_
    ) external view returns (SubscriptionStatus[] memory statuses);

    function viewSubscribers(
        address paymentToken_
    ) external view returns (address[] memory);

    function viewSupportedTokens() external view returns (address[] memory);

    function isUseStorage() external view returns (bool);
}
