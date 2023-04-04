// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IPermit2} from "../utils/permit2/interfaces/IPermit2.sol";

/**
@title ISubscriptionManager
@dev The interface for the SubscriptionManager contract.
*/

interface ISubscriptionManager {
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

    struct ClaimInfo {
        address token;
        address account;
    }

    event Claimed(address indexed operator, uint256[] success, bytes[] results);

    event NewFeeInfo(
        address indexed operator,
        FeeInfo indexed oldFeeInfo,
        FeeInfo indexed newFeeInfo
    );

    function setFeeInfo(address recipient_, uint96 amount_) external;

    function claimFees(
        ClaimInfo[] calldata claimInfo_
    ) external returns (uint256[] memory success, bytes[] memory results);
}
