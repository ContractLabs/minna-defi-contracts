// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

import {SigUtils} from "./utils/SigUtils.sol";
import {MockERC20} from "./utils/MockERC20Permit.sol";
import {
    ISubscriptionManager,
    SubscriptionManager
} from "contracts/SubscriptionManager.sol";

contract SubscriptionManagerTest is Test {
    bytes32 public constant OPERATOR_ROLE =
        0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929;
    bytes32 public constant UPGRADER_ROLE =
        0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3;
    bytes32 public constant TREASURER_ROLE =
        0x3496e2e73c4d42b75d702e60d9e48102720b8691234415963a5a857b86425d07;

    uint96 defaultFee = 50;
    uint96 defaultAmount = 1000;
    uint96 insufficientBalance = 10;

    address internal bob = vm.addr(0x1);
    address internal alice = vm.addr(0x2);
    address internal operator = vm.addr(0x3);
    address internal upgrader = vm.addr(0x4);
    address internal recipient = vm.addr(0x5);


    MockERC20 internal token = new MockERC20();

    SubscriptionManager internal manager;

    event Distributed(
        address indexed operator,
        uint256[] success,
        bytes[] results
    );

    event NewPayment(
        address indexed operator,
        address indexed from,
        address indexed to
    );

    event Claimed(address indexed operator, uint256[] success, bytes[] results);

    event NewFeeInfo(
        address indexed operator,
        ISubscriptionManager.FeeInfo indexed oldFeeInfo,
        ISubscriptionManager.FeeInfo indexed newFeeInfo
    );

    function setUp() public {
        vm.startPrank(upgrader);
        manager = new SubscriptionManager();
        manager.initialize(
            operator,
            address(token),
            defaultFee,
            recipient
        );
        vm.stopPrank();

        token.mint(address(manager), defaultAmount);
        token.mint(bob, defaultAmount);
        token.mint(alice, defaultAmount);

        vm.startPrank(bob);
        token.approve(address(manager), defaultAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        token.approve(address(manager), insufficientBalance);
        vm.stopPrank();
    }

    function testSetFeeSuccess() public {
        ISubscriptionManager.FeeInfo memory _feeInfo = ISubscriptionManager.FeeInfo(
            recipient,
            defaultFee
        );

        ISubscriptionManager.FeeInfo memory feeInfo_ = ISubscriptionManager.FeeInfo(
            recipient,
            30
        );

        vm.expectEmit(true, true, false, true);
        emit NewFeeInfo(recipient, _feeInfo, feeInfo_);

        vm.startPrank(recipient);
        manager.setFeeInfo(recipient, 30);
        vm.stopPrank();
    } 

    function testSetFeeFailUnauthorized() public {
        bytes4 selector = bytes4(
            keccak256("AccessControl__RoleMissing(bytes32,address)")
        );
        vm.expectRevert(abi.encodeWithSelector(selector, TREASURER_ROLE, bob));

        vm.startPrank(bob);
        manager.setFeeInfo(bob, 30);
        vm.stopPrank();
    } 

    function testClaimOperator() public {
        address[] memory addresses = new address[](2);
        addresses[0] = bob;
        addresses[1] = alice;

        vm.startPrank(operator);
        manager.claimFees(addresses);
        vm.stopPrank();

        assertEq(token.balanceOf(address(manager)), defaultAmount + defaultFee);
        assertEq(token.balanceOf(bob), defaultAmount - defaultFee);
        assertEq(token.balanceOf(alice), defaultAmount);

    }

    function testClaimRecipient() public {
        address[] memory addresses = new address[](2);
        addresses[0] = bob;
        addresses[1] = alice;

        vm.startPrank(recipient);
        manager.claimFees(addresses);
        vm.stopPrank();

        assertEq(token.balanceOf(address(manager)), defaultAmount + defaultFee);
        assertEq(token.balanceOf(bob), defaultAmount - defaultFee);
        assertEq(token.balanceOf(alice), defaultAmount);
    }

    function testClaimUnauthorized() public {
        address[] memory addresses = new address[](2);
        addresses[0] = bob;
        addresses[1] = alice;

        bytes4 selector = bytes4(
            keccak256("AccessControl__RoleMissing(bytes32,address)")
        );
        vm.expectRevert(abi.encodeWithSelector(selector, OPERATOR_ROLE, bob));

        vm.startPrank(bob);
        manager.claimFees(addresses);
        vm.stopPrank();
    }

    function testDistributeBonus() public {
        ISubscriptionManager.Bonus[] memory bonuses = new ISubscriptionManager.Bonus[](2);
        bonuses[0] = ISubscriptionManager.Bonus(bob, 15);
        bonuses[1] = ISubscriptionManager.Bonus(alice, 10);
        
        vm.startPrank(recipient);
        manager.distributeBonuses(bonuses);
        vm.stopPrank();

        assertEq(token.balanceOf(address(manager)), defaultAmount - 25);
        assertEq(token.balanceOf(bob), defaultAmount + 15);
        assertEq(token.balanceOf(alice), defaultAmount + 10);
    }

    function testDistributeBonusUnauthorized() public {
        ISubscriptionManager.Bonus[] memory bonuses = new ISubscriptionManager.Bonus[](2);
        bonuses[0] = ISubscriptionManager.Bonus(bob, 15);
        bonuses[1] = ISubscriptionManager.Bonus(alice, 10);

        bytes4 selector = bytes4(
            keccak256("AccessControl__RoleMissing(bytes32,address)")
        );
        vm.expectRevert(abi.encodeWithSelector(selector, TREASURER_ROLE, bob));
        
        vm.startPrank(bob);
        manager.distributeBonuses(bonuses);
        vm.stopPrank();
    }
}