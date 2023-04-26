// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
@title ISubscriptionManager
@dev The interface for the SubscriptionManager contract.
*/

interface ISubscriptionManager {
    error SubscriptionManager__Unclaimed();
    /**
    @dev Error emitted when an invalid argument is provided.
    */
    error SubscriptionManager__InvalidArgument();
    /**
    @dev Error emitted when the caller is not authorized to perform the action.
    @param caller The address of the unauthorized caller.
    */
    error SubscriptionManager__Unauthorized(address caller);

    struct FeeInfo {
        address recipient;
        uint96 amount;
    }

    struct Bonus {
        address recipient;
        uint256 bonus;
    }

    event Distributed(address indexed operator, uint256[] success, bytes[] results);

    event NewPayment(
        address indexed operator,
        address indexed from,
        address indexed to
    );

    event Claimed(address indexed operator, uint256[] success, bytes[] results);

    event NewFeeInfo(
        address indexed operator,
        FeeInfo indexed oldFeeInfo,
        FeeInfo indexed newFeeInfo
    );

    function setPayment(address payment_) external;

    function setFeeInfo(address recipient_, uint96 amount_) external;

    function claimFees(
        address[] calldata accounts_
    ) external returns (uint256[] memory success, bytes[] memory results);
}
