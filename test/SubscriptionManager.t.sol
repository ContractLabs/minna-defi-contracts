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
import {PermitSignature} from "./utils/PermitSignature.sol";
import {Permit2} from "contracts/utils/permit2/Permit2.sol";
import {IPermit2} from "contracts/utils/permit2/interfaces/IPermit2.sol";
import {
    IAllowanceTransfer
} from "contracts/utils/permit2/interfaces/IAllowanceTransfer.sol";

contract SubscriptionManagerTest is Test, PermitSignature {
    uint32 dirtyNonce = 1;
    uint48 defaultNonce = 0;
    uint48 defaultExpiration = uint48(block.timestamp + 4 weeks);
    uint96 defaultAmount = 1e18;
    uint96 defaultFee = 100;
    uint96 insufficientBalance = 10;

    uint256 defaultDeadline = block.timestamp + 1 days;
    uint256 internal ownerPrivateKey = 0xA11CE;
    uint256 internal adminPrivateKey = 0xB0B;
    uint256 internal recipientPrivateKey = 0xCDEF;

    address internal owner = vm.addr(ownerPrivateKey);
    address internal admin = vm.addr(adminPrivateKey);
    address internal recipient = vm.addr(recipientPrivateKey);

    Permit2 internal permit2 = new Permit2();
    MockERC20 internal token = new MockERC20();
    MockERC20 internal token1 = new MockERC20();
    MockERC20 internal token2 = new MockERC20();

    SubscriptionManager internal manager;

    SigUtils internal sigUtils = new SigUtils(token.DOMAIN_SEPARATOR());
    SigUtils internal sigUtils2 = new SigUtils(token2.DOMAIN_SEPARATOR());

    event Blacklisted(address indexed operator, address[] blacklisted);
    event Claimed(address indexed operator, bool[] success, bytes[] results);

    function setUp() public {
        vm.startPrank(admin);
        manager = new SubscriptionManager(
            defaultFee,
            true,
            IPermit2(address(permit2)),
            recipient
        );

        ISubscriptionManager.FeeToken[]
            memory feeTokens = new ISubscriptionManager.FeeToken[](2);
        feeTokens[0] = ISubscriptionManager.FeeToken(
            address(token),
            true,
            false
        );
        feeTokens[1] = ISubscriptionManager.FeeToken(
            address(token1),
            true,
            true
        );

        manager.setFeeTokens(feeTokens);
        vm.stopPrank();
        token.mint(owner, type(uint96).max);
        token1.mint(owner, type(uint96).max);
        vm.startPrank(owner);
        token1.approve(address(permit2), defaultAmount);
        vm.stopPrank();
        token2.mint(owner, type(uint96).max);
    }

    function testSubscribeSuccessWithPermit() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: address(manager),
            value: defaultAmount,
            nonce: defaultNonce,
            deadline: defaultDeadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        ISubscriptionManager.Payment memory payment = ISubscriptionManager
            .Payment({
                token: address(token),
                nonce: defaultNonce,
                amount: defaultAmount,
                deadline: defaultDeadline,
                approvalExpiration: defaultExpiration,
                signature: signature
            });
        manager.subscribe(owner, 4 weeks, payment);

        assertEq(token.balanceOf(recipient), defaultFee);
    }

    function testSubscribeFailWithUnsupportedToken() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: address(manager),
            value: defaultAmount,
            nonce: defaultNonce,
            deadline: defaultDeadline
        });

        bytes32 digest = sigUtils2.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        ISubscriptionManager.Payment memory payment = ISubscriptionManager
            .Payment({
                token: address(token2),
                nonce: defaultNonce,
                amount: defaultAmount,
                deadline: defaultDeadline,
                approvalExpiration: defaultExpiration,
                signature: signature
            });

        bytes4 selector = bytes4(
            keccak256("SubscriptionManager__UnsupportedToken(address)")
        );
        vm.expectRevert(abi.encodeWithSelector(selector, address(token2)));

        manager.subscribe(owner, 4 weeks, payment);
    }

    function testSubscribeFailWithInsufficientBalance() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: address(manager),
            value: insufficientBalance,
            nonce: defaultNonce,
            deadline: defaultDeadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        ISubscriptionManager.Payment memory payment = ISubscriptionManager
            .Payment({
                token: address(token),
                nonce: defaultNonce,
                amount: insufficientBalance,
                deadline: defaultDeadline,
                approvalExpiration: defaultExpiration,
                signature: signature
            });

        bytes4 selector = bytes4(
            keccak256("SubscriptionManager__InsufficientBalance()")
        );
        vm.expectRevert(abi.encodeWithSelector(selector));
        manager.subscribe(owner, 4 weeks, payment);

        vm.startPrank(admin);
        manager.claimFees(address(token));
        manager.claimFees(address(token1));
        vm.stopPrank();
    }

    // function testSubscribeStandardPermitFailWithInvalidDuration() public {
    //     SigUtils.Permit memory permit = SigUtils.Permit({
    //         owner: owner,
    //         spender: address(manager),
    //         value: defaultAmount,
    //         nonce: defaultNonce,
    //         deadline: defaultDeadline
    //     });

    //     bytes32 digest = sigUtils.getTypedDataHash(permit);
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
    //     bytes memory signature = abi.encodePacked(r, s, v);

    //     ISubscriptionManager.Payment memory payment = ISubscriptionManager
    //         .Payment({
    //             token: address(token),
    //             nonce: defaultNonce,
    //             amount: defaultAmount,
    //             deadline: defaultDeadline,
    //             approvalExpiration: defaultExpiration,
    //             signature: signature
    //         });

    //     bytes4 selector = bytes4(
    //         keccak256("SubscriptionManager__InsufficientBalance()")
    //     );
    //     vm.expectRevert(abi.encodeWithSelector(selector));
    //     manager.subscribe(owner, uint64(block.timestamp), payment);
    // }

    function testSubscribeSuccessWithPermit2() public {
        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer
            .PermitDetails(
                address(token1),
                defaultAmount,
                defaultExpiration,
                defaultNonce
            );
        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer
            .PermitSingle({
                details: details,
                spender: address(manager),
                sigDeadline: defaultDeadline
            });
        bytes memory signature = getPermitSignature(
            permit,
            ownerPrivateKey,
            permit2.DOMAIN_SEPARATOR()
        );
        ISubscriptionManager.Payment memory payment = ISubscriptionManager
            .Payment({
                token: address(token1),
                nonce: defaultNonce,
                amount: defaultAmount,
                deadline: defaultDeadline,
                approvalExpiration: defaultExpiration,
                signature: signature
            });

        manager.subscribe(owner, 4 weeks, payment);

        assertEq(token1.balanceOf(recipient), defaultFee);
    }

    function testClaimFeesUseStorageWithStandardPermitSuccess() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: address(manager),
            value: defaultAmount,
            nonce: defaultNonce,
            deadline: defaultDeadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        ISubscriptionManager.Payment memory payment = ISubscriptionManager
            .Payment({
                token: address(token),
                nonce: defaultNonce,
                amount: defaultAmount,
                deadline: defaultDeadline,
                approvalExpiration: defaultExpiration,
                signature: signature
            });

        vm.startPrank(owner);
        manager.subscribe(owner, 4 weeks, payment);
        vm.stopPrank();

        vm.warp(4 weeks + 1 seconds);
        vm.startPrank(admin);
        manager.claimFees(address(token));
        vm.stopPrank();

        assertEq(token.balanceOf(recipient), defaultFee * 2);
    }

    function testClaimFeesBlacklistFail() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: address(manager),
            value: defaultFee,
            nonce: defaultNonce,
            deadline: defaultDeadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        ISubscriptionManager.Payment memory payment = ISubscriptionManager
            .Payment({
                token: address(token),
                nonce: defaultNonce,
                amount: defaultFee,
                deadline: defaultDeadline,
                approvalExpiration: defaultExpiration,
                signature: signature
            });

        vm.startPrank(owner);
        manager.subscribe(owner, 4 weeks, payment);
        vm.stopPrank();

        vm.warp(4 weeks + 1 seconds);

        bool[] memory success = new bool[](1);
        success[0] = false;
        bytes[] memory result = new bytes[](1);
        result[0] = "";

        address[] memory blacklist = new address[](1);
        blacklist[0] = owner;

        vm.expectEmit(true, true, true, true);
        vm.recordLogs();
        emit Claimed(admin, success, result);
        emit Blacklisted(admin, blacklist);

        vm.startPrank(admin);
        manager.claimFees(address(token));
        vm.stopPrank();
    }

    function testClaimFeesUseStorageWithPermit2Success() public {
        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer
            .PermitDetails(
                address(token1),
                defaultAmount,
                defaultExpiration,
                defaultNonce
            );
        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer
            .PermitSingle({
                details: details,
                spender: address(manager),
                sigDeadline: defaultDeadline
            });
        bytes memory signature = getPermitSignature(
            permit,
            ownerPrivateKey,
            permit2.DOMAIN_SEPARATOR()
        );
        ISubscriptionManager.Payment memory payment = ISubscriptionManager
            .Payment({
                token: address(token1),
                nonce: defaultNonce,
                amount: defaultAmount,
                deadline: defaultDeadline,
                approvalExpiration: defaultExpiration,
                signature: signature
            });
        vm.startPrank(owner);
        manager.subscribe(owner, 4 weeks, payment);
        vm.stopPrank();

        vm.warp(4 weeks + 1 seconds);
        vm.startPrank(admin);
        manager.claimFees(address(token1));
        vm.stopPrank();

        assertEq(token1.balanceOf(recipient), defaultFee * 2);
    }
}
