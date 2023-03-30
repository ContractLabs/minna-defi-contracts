// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IPermit2} from "../utils/permit2/interfaces/IPermit2.sol";

/**
@title ISubscriptionManager
@dev The interface for the SubscriptionManager contract.
*/

interface ISubscriptionManager {
    /**
    @dev Error emitted when the caller is on an unsupported chain.
    */
    error SubscriptionManager__InvalidChain();
    /**
    @dev Error emitted when an invalid argument is provided.
    */
    error SubscriptionManager__InvalidArgument();
    /**
    @dev Error emitted when the caller has insufficient balance to make a payment.
    */
    error SubscriptionManager__InsufficientBalance();
    /**
    @dev Error emitted when the caller is not authorized to perform the action.
    @param caller The address of the unauthorized caller.
    */
    error SubscriptionManager__Unauthorized(address caller);
    /**
    @dev Error emitted when the specified token is not supported.
    @param token The address of the unsupported token.
    */
    error SubscriptionManager__UnsupportedToken(address token);

    /**
    @dev Struct representing a fee token used for payment of fees.
    @param token The address of the fee token.
    @param isSet Indicates whether the fee token has been set.
    @param usePermit2 Indicates whether the fee token uses the Permit2 interface.
    */
    struct Payment {
        address token;
        uint48 nonce;
        uint160 amount;
        uint256 deadline;
        uint48 approvalExpiration;
        bytes signature;
    }

    /**
    @dev Struct representing information about fees.
    @param recipient The address of the fee recipient.
    @param amount The amount of fees.
    */
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
