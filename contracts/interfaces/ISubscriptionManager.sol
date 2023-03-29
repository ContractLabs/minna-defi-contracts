// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ISubscriptionManager {
    error SubscriptionManager__InvalidChain();
    error SubscriptionManager__Unauthorized(address caller);
    error SubscriptionManager__UnsupportedToken(address token);

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
        bool isBlacklisted;
    }

    event Claimed(address indexed operator, bool[] success, bytes[] results);

    event NewFeeInfo(
        address indexed operator,
        FeeInfo indexed oldFeeInfo,
        FeeInfo indexed newFeeInfo
    );

    event FeeTokensUpdated(address indexed operator, FeeToken[] feeTokens);

    function setWhichChainUseStorage(uint256 chainId_) external;

    function setFeeInfo(address recipient_, uint96 amount_) external;

    function setFeeTokens(FeeToken[] calldata feeTokens_) external;

    function subscribe(
        address token_,
        address account_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external;

    function claimFees(address paymentToken_) external;

    function claimFees(ClaimInfo[] calldata claimInfo_) external;

    function viewSubscribers(
        address paymentToken_
    ) external view returns (Subscriber[] memory);

    function viewSupportedTokens() external view returns (address[] memory);
}
