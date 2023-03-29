// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ISubscriptionManager {
    error SubscriptionManager__InvalidChain();
    error SubscriptionManager__Unauthorized(address caller);
    error SubscriptionManager__UnsupportedToken(address token);
    error SubscriptionManager__InvalidDeadline(uint256 deadline);

    struct TokenPermission {
        address token;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }

    struct FeeToken {
        address token;
        bool isSet;
    }

    struct FeeInfo {
        address recipient;
        uint96 amount;
    }

    struct ClaimInfo {
        address token;
        address account;
    }

    struct Subscriber {
        address account;
        uint64 duration;
    }

    event ToggleUseStorage(address indexed operator, bool indexed isUse);

    event Claimed(address indexed operator, bool[] success, bytes[] results);

    event NewFeeInfo(
        address indexed operator,
        FeeInfo indexed oldFeeInfo,
        FeeInfo indexed newFeeInfo
    );

    event FeeTokensUpdated(address indexed operator, FeeToken[] feeTokens);

    function toggleUseStorage() external;

    function setFeeInfo(address recipient_, uint96 amount_) external;

    function setFeeTokens(FeeToken[] calldata feeTokens_) external;

    function subscribe(
        address token_,
        address account_,
        uint256 nonce_,
        uint256 deadline_,
        bytes calldata signature_
    ) external;

    function claimFees(address paymentToken_) external;

    function claimFees(ClaimInfo[] calldata claimInfo_) external;

    function viewClaimableAllowance(
        address token_
    )
        external
        view
        returns (address[] memory account, uint256[] memory allowances);

    function viewSubscribers(
        address paymentToken_
    ) external view returns (address[] memory);

    function viewSupportedTokens() external view returns (address[] memory);

    function isUseStorage() external view returns (bool);
}
