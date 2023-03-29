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
import {IAllowanceTransfer} from "contracts/utils/permit2/interfaces/IAllowanceTransfer.sol";

contract SubscriptionManagerTest is Test, PermitSignature {
    uint256 internal ownerPrivateKey = 0xA11CE;
    uint256 internal spenderPrivateKey = 0xB0B;
    uint256 internal recipientPrivateKey = 0xCDEF;

    address internal owner = vm.addr(ownerPrivateKey);
    address internal spender = vm.addr(spenderPrivateKey);
    address internal recipient = vm.addr(recipientPrivateKey);

    Permit2 internal permit2 = new Permit2();
    MockERC20 internal token = new MockERC20();
    MockERC20 internal token1 = new MockERC20();


    SubscriptionManager internal manager =
        new SubscriptionManager(
            1000,
            true,
            IPermit2(address(permit2)),
            recipient
        );

    SigUtils internal sigUtils = new SigUtils(token.DOMAIN_SEPARATOR());

    function setUp() public {
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

        token.mint(owner, 1e18);
        token1.mint(owner, 1e18);
        // token1.approve(address(permit2), 1e18);
        manager.setFeeTokens(feeTokens);
    }

    function testSubscribeSuccessWithPermit() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: address(manager),
            value: 1e18,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        ISubscriptionManager.Payment memory payment = ISubscriptionManager
            .Payment({
                token: address(token),
                nonce: 0,
                amount: 1e18,
                deadline: 1 days,
                approvalExpiration: 4 weeks,
                signature: signature
            });

        manager.subscribe(owner, 4 weeks, payment);

        assertEq(token.balanceOf(recipient), 1000);
        assertEq(token.balanceOf(owner), 1e18 - 1000);
    }

    function testSubscribeSuccessWithPermit2() public {
        // IAllowanceTransfer.PermitSingle memory permit = defaultERC20PermitAllowance(address(token1), 1e18, 1 days, 0);
        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer.PermitDetails(address(token1), 1e18, 4 weeks, 0);
        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: details,
            spender: address(manager),
            sigDeadline: 1 days
        });
        bytes memory signature = getPermitSignature(permit, ownerPrivateKey, permit2.DOMAIN_SEPARATOR());
        ISubscriptionManager.Payment memory payment = ISubscriptionManager
            .Payment({
                token: address(token1),
                nonce: 0,
                amount: 1e18,
                deadline: 1 days,
                approvalExpiration: 4 weeks,
                signature: signature
            });

        manager.subscribe(owner, 4 weeks, payment);

        assertEq(token1.balanceOf(recipient), 1000);
        assertEq(token1.balanceOf(owner), 1e18 - 1000);
    }
}
