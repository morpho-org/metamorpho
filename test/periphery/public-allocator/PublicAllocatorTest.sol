// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "../../../lib/forge-std/src/Test.sol";
import {
    IntegrationTest,
    MarketAllocation,
    MarketParamsLib,
    MarketParams,
    IMorpho,
    Id,
    stdError
} from "../../helpers/IntegrationTest.sol";
import {
    PublicAllocator,
    FlowCapsConfig,
    Withdrawal,
    FlowCaps
} from "../../../src/periphery/public-allocator/PublicAllocator.sol";
import {ErrorsLib} from "../../../src/periphery/public-allocator/libraries/ErrorsLib.sol";
import {EventsLib} from "../../../src/periphery/public-allocator/libraries/EventsLib.sol";
import {UtilsLib} from "../../../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {
    IPublicAllocator,
    MAX_SETTABLE_FLOW_CAP
} from "../../../src/periphery/public-allocator/interfaces/IPublicAllocator.sol";
import {MorphoBalancesLib} from "../../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";

uint256 constant CAP2 = 100e18;
uint256 constant INITIAL_DEPOSIT = 4 * CAP2;

contract CantReceive {
    receive() external payable {
        require(false, "cannot receive");
    }
}

// Withdrawal sorting snippet
library SortWithdrawals {
    using MarketParamsLib for MarketParams;
    // Sorts withdrawals in-place using gnome sort.
    // Does not detect duplicates.
    // The sort will not be in-place if you pass a storage array.

    function sort(Withdrawal[] memory ws) internal pure returns (Withdrawal[] memory) {
        uint256 i;
        while (i < ws.length) {
            if (i == 0 || Id.unwrap(ws[i].marketParams.id()) >= Id.unwrap(ws[i - 1].marketParams.id())) {
                i++;
            } else {
                (ws[i], ws[i - 1]) = (ws[i - 1], ws[i]);
                i--;
            }
        }
        return ws;
    }
}

contract PublicAllocatorTest is IntegrationTest {
    IPublicAllocator public publicAllocator;
    Withdrawal[] internal withdrawals;
    FlowCapsConfig[] internal flowCaps;

    using SortWithdrawals for Withdrawal[];
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;

    function setUp() public override {
        super.setUp();

        publicAllocator = IPublicAllocator(address(new PublicAllocator(address(vault.MORPHO()))));
        vm.prank(OWNER);
        vault.setIsAllocator(address(publicAllocator), true);

        loanToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);

        vm.prank(SUPPLIER);
        vault.deposit(INITIAL_DEPOSIT, ONBEHALF);

        _setCap(allMarkets[0], CAP2);
        _sortSupplyQueueIdleLast();
    }

    function testAdmin() public {
        assertEq(publicAllocator.admin(address(vault)), address(0));
    }

    function testSetAdmin() public {
        vm.prank(OWNER);
        publicAllocator.setAdmin(address(vault), address(1));
        assertEq(publicAllocator.admin(address(vault)), address(1));
    }

    function testSetAdminByAdmin(address sender, address newAdmin) public {
        vm.assume(publicAllocator.admin(address(vault)) != sender);
        vm.assume(sender != newAdmin);
        vm.prank(OWNER);
        publicAllocator.setAdmin(address(vault), sender);
        vm.prank(sender);
        publicAllocator.setAdmin(address(vault), newAdmin);
        assertEq(publicAllocator.admin(address(vault)), newAdmin);
    }

    function testSetAdminAlreadySet() public {
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vm.prank(OWNER);
        publicAllocator.setAdmin(address(vault), address(0));
    }

    function testSetAdminAccessFail(address sender, address newAdmin) public {
        vm.assume(sender != OWNER);
        vm.assume(publicAllocator.admin(address(vault)) != sender);
        vm.assume(publicAllocator.admin(address(vault)) != newAdmin);

        vm.expectRevert(ErrorsLib.NotAdminNorVaultOwner.selector);
        vm.prank(sender);
        publicAllocator.setAdmin(address(vault), newAdmin);
    }

    function testReallocateCapZeroOutflowByDefault(uint128 flow) public {
        flow = uint128(bound(flow, 1, CAP2));
        flowCaps.push(
            FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: 0})})
        );
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);
        withdrawals.push(Withdrawal({marketParams: idleParams, amount: flow}));
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.MaxOutflowExceeded.selector, idleParams.id()));
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);
    }

    function testReallocateCapZeroInflowByDefault(uint128 flow) public {
        flow = uint128(bound(flow, 1, CAP2));
        deal(address(loanToken), address(vault), flow);
        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: 0, maxOut: MAX_SETTABLE_FLOW_CAP})}));
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);
        withdrawals.push(Withdrawal({marketParams: idleParams, amount: flow}));
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.MaxInflowExceeded.selector, allMarkets[0].id()));
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);
    }

    function testConfigureFlowAccessFail(address sender) public {
        vm.assume(sender != OWNER);
        vm.assume(publicAllocator.admin(address(vault)) != sender);

        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: 0, maxOut: 0})}));

        vm.prank(sender);
        vm.expectRevert(ErrorsLib.NotAdminNorVaultOwner.selector);
        publicAllocator.setFlowCaps(address(vault), flowCaps);
    }

    function testTransferFeeAccessFail(address sender, address payable recipient) public {
        vm.assume(sender != OWNER);
        vm.assume(publicAllocator.admin(address(vault)) != sender);
        vm.prank(sender);
        vm.expectRevert(ErrorsLib.NotAdminNorVaultOwner.selector);
        publicAllocator.transferFee(address(vault), recipient);
    }

    function testSetFeeAccessFail(address sender, uint256 fee) public {
        vm.assume(sender != OWNER);
        vm.assume(publicAllocator.admin(address(vault)) != sender);
        vm.prank(sender);
        vm.expectRevert(ErrorsLib.NotAdminNorVaultOwner.selector);
        publicAllocator.setFee(address(vault), fee);
    }

    function testSetFee(uint256 fee) public {
        vm.assume(fee != publicAllocator.fee(address(vault)));
        vm.prank(OWNER);
        vm.expectEmit(address(publicAllocator));
        emit EventsLib.SetFee(OWNER, address(vault), fee);
        publicAllocator.setFee(address(vault), fee);
        assertEq(publicAllocator.fee(address(vault)), fee);
    }

    function testSetFeeByAdmin(uint256 fee, address sender) public {
        vm.assume(publicAllocator.admin(address(vault)) != sender);
        vm.assume(fee != publicAllocator.fee(address(vault)));
        vm.prank(OWNER);
        publicAllocator.setAdmin(address(vault), sender);
        vm.prank(sender);
        vm.expectEmit(address(publicAllocator));
        emit EventsLib.SetFee(sender, address(vault), fee);
        publicAllocator.setFee(address(vault), fee);
        assertEq(publicAllocator.fee(address(vault)), fee);
    }

    function testSetFeeAlreadySet(uint256 fee) public {
        vm.assume(fee != publicAllocator.fee(address(vault)));
        vm.prank(OWNER);
        publicAllocator.setFee(address(vault), fee);
        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        publicAllocator.setFee(address(vault), fee);
    }

    function testSetFlowCaps(uint128 in0, uint128 out0, uint128 in1, uint128 out1) public {
        in0 = uint128(bound(in0, 0, MAX_SETTABLE_FLOW_CAP));
        out0 = uint128(bound(out0, 0, MAX_SETTABLE_FLOW_CAP));
        in1 = uint128(bound(in1, 0, MAX_SETTABLE_FLOW_CAP));
        out1 = uint128(bound(out1, 0, MAX_SETTABLE_FLOW_CAP));

        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: in0, maxOut: out0})}));
        flowCaps.push(FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: in1, maxOut: out1})}));

        vm.expectEmit(address(publicAllocator));
        emit EventsLib.SetFlowCaps(OWNER, address(vault), flowCaps);

        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        FlowCaps memory flowCap;
        flowCap = publicAllocator.flowCaps(address(vault), idleParams.id());
        assertEq(flowCap.maxIn, in0);
        assertEq(flowCap.maxOut, out0);

        flowCap = publicAllocator.flowCaps(address(vault), allMarkets[0].id());
        assertEq(flowCap.maxIn, in1);
        assertEq(flowCap.maxOut, out1);
    }

    function testSetFlowCapsByAdmin(uint128 in0, uint128 out0, uint128 in1, uint128 out1, address sender) public {
        vm.assume(publicAllocator.admin(address(vault)) != sender);
        in0 = uint128(bound(in0, 0, MAX_SETTABLE_FLOW_CAP));
        out0 = uint128(bound(out0, 0, MAX_SETTABLE_FLOW_CAP));
        in1 = uint128(bound(in1, 0, MAX_SETTABLE_FLOW_CAP));
        out1 = uint128(bound(out1, 0, MAX_SETTABLE_FLOW_CAP));

        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: in0, maxOut: out0})}));
        flowCaps.push(FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: in1, maxOut: out1})}));

        vm.prank(OWNER);
        publicAllocator.setAdmin(address(vault), sender);

        vm.expectEmit(address(publicAllocator));
        emit EventsLib.SetFlowCaps(sender, address(vault), flowCaps);

        vm.prank(sender);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        FlowCaps memory flowCap;
        flowCap = publicAllocator.flowCaps(address(vault), idleParams.id());
        assertEq(flowCap.maxIn, in0);
        assertEq(flowCap.maxOut, out0);

        flowCap = publicAllocator.flowCaps(address(vault), allMarkets[0].id());
        assertEq(flowCap.maxIn, in1);
        assertEq(flowCap.maxOut, out1);
    }

    function testPublicReallocateEvent(uint128 flow, address sender) public {
        flow = uint128(bound(flow, 1, CAP2 / 2));

        // Prepare public reallocation from 2 markets to 1
        _setCap(allMarkets[1], CAP2);

        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({marketParams: idleParams, assets: INITIAL_DEPOSIT - flow});
        allocations[1] = MarketAllocation({marketParams: allMarkets[1], assets: flow});
        vm.prank(OWNER);
        vault.reallocate(allocations);

        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: 0, maxOut: flow})}));
        flowCaps.push(FlowCapsConfig({id: allMarkets[1].id(), caps: FlowCaps({maxIn: 0, maxOut: flow})}));
        flowCaps.push(FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: 2 * flow, maxOut: 0})}));
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        withdrawals.push(Withdrawal({marketParams: idleParams, amount: flow}));
        withdrawals.push(Withdrawal({marketParams: allMarkets[1], amount: flow}));

        vm.expectEmit(address(publicAllocator));
        emit EventsLib.PublicWithdrawal(sender, address(vault), idleParams.id(), flow);
        emit EventsLib.PublicWithdrawal(sender, address(vault), allMarkets[1].id(), flow);
        emit EventsLib.PublicReallocateTo(sender, address(vault), allMarkets[0].id(), 2 * flow);

        vm.prank(sender);
        publicAllocator.reallocateTo(address(vault), withdrawals.sort(), allMarkets[0]);
    }

    function testReallocateNetting(uint128 flow) public {
        flow = uint128(bound(flow, 1, CAP2));

        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: 0, maxOut: flow})}));
        flowCaps.push(FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: flow, maxOut: 0})}));
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        withdrawals.push(Withdrawal({marketParams: idleParams, amount: flow}));
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);

        delete withdrawals;
        withdrawals.push(Withdrawal({marketParams: allMarkets[0], amount: flow}));
        publicAllocator.reallocateTo(address(vault), withdrawals, idleParams);
    }

    function testReallocateReset(uint128 flow) public {
        flow = uint128(bound(flow, 1, CAP2 / 2));

        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: 0, maxOut: flow})}));
        flowCaps.push(FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: flow, maxOut: 0})}));
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        withdrawals.push(Withdrawal({marketParams: idleParams, amount: flow}));
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);

        delete flowCaps;
        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: 0, maxOut: flow})}));
        flowCaps.push(FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: flow, maxOut: 0})}));
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        delete withdrawals;

        withdrawals.push(Withdrawal({marketParams: idleParams, amount: flow}));
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);
    }

    function testFeeAmountSuccess(uint256 requiredFee) public {
        vm.assume(requiredFee != publicAllocator.fee(address(vault)));
        vm.prank(OWNER);
        publicAllocator.setFee(address(vault), requiredFee);

        vm.deal(address(this), requiredFee);

        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: 0, maxOut: 1 ether})}));
        flowCaps.push(FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: 1 ether, maxOut: 0})}));
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);
        withdrawals.push(Withdrawal({marketParams: idleParams, amount: 1 ether}));

        publicAllocator.reallocateTo{value: requiredFee}(address(vault), withdrawals, allMarkets[0]);
    }

    function testFeeAmountFail(uint256 requiredFee, uint256 givenFee) public {
        vm.assume(requiredFee > 0);
        vm.assume(requiredFee != givenFee);

        vm.prank(OWNER);
        publicAllocator.setFee(address(vault), requiredFee);

        vm.deal(address(this), givenFee);
        vm.expectRevert(ErrorsLib.IncorrectFee.selector);
        publicAllocator.reallocateTo{value: givenFee}(address(vault), withdrawals, allMarkets[0]);
    }

    function testTransferFeeSuccess() public {
        vm.prank(OWNER);
        publicAllocator.setFee(address(vault), 0.001 ether);

        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: 0, maxOut: 2 ether})}));
        flowCaps.push(FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: 2 ether, maxOut: 0})}));
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);
        withdrawals.push(Withdrawal({marketParams: idleParams, amount: 1 ether}));

        publicAllocator.reallocateTo{value: 0.001 ether}(address(vault), withdrawals, allMarkets[0]);
        publicAllocator.reallocateTo{value: 0.001 ether}(address(vault), withdrawals, allMarkets[0]);

        uint256 before = address(this).balance;

        vm.prank(OWNER);
        publicAllocator.transferFee(address(vault), payable(address(this)));

        assertEq(address(this).balance - before, 2 * 0.001 ether, "wrong fee transferred");
    }

    function testTransferFeeByAdminSuccess(address sender) public {
        vm.assume(publicAllocator.admin(address(vault)) != sender);
        vm.prank(OWNER);
        publicAllocator.setAdmin(address(vault), sender);
        vm.prank(sender);
        publicAllocator.setFee(address(vault), 0.001 ether);

        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: 0, maxOut: 2 ether})}));
        flowCaps.push(FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: 2 ether, maxOut: 0})}));
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);
        withdrawals.push(Withdrawal({marketParams: idleParams, amount: 1 ether}));

        publicAllocator.reallocateTo{value: 0.001 ether}(address(vault), withdrawals, allMarkets[0]);
        publicAllocator.reallocateTo{value: 0.001 ether}(address(vault), withdrawals, allMarkets[0]);

        uint256 before = address(this).balance;

        vm.prank(sender);
        publicAllocator.transferFee(address(vault), payable(address(this)));

        assertEq(address(this).balance - before, 2 * 0.001 ether, "wrong fee transferred");
    }

    function testTransferFeeFail() public {
        vm.prank(OWNER);
        publicAllocator.setFee(address(vault), 0.001 ether);

        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: 0, maxOut: 1 ether})}));
        flowCaps.push(FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: 1 ether, maxOut: 0})}));
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);
        withdrawals.push(Withdrawal({marketParams: idleParams, amount: 1 ether}));

        publicAllocator.reallocateTo{value: 0.001 ether}(address(vault), withdrawals, allMarkets[0]);

        CantReceive cr = new CantReceive();
        vm.expectRevert("cannot receive");
        vm.prank(OWNER);
        publicAllocator.transferFee(address(vault), payable(address(cr)));
    }

    function testTransferOKOnZerobalance() public {
        vm.prank(OWNER);
        publicAllocator.transferFee(address(vault), payable(address(this)));
    }

    receive() external payable {}

    function testMaxOutNoOverflow(uint128 flow) public {
        flow = uint128(bound(flow, 1, CAP2));

        // Set flow limits with supply market's maxOut to max
        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: 0, maxOut: MAX_SETTABLE_FLOW_CAP})}));
        flowCaps.push(
            FlowCapsConfig({
                id: allMarkets[0].id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: MAX_SETTABLE_FLOW_CAP})
            })
        );
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        withdrawals.push(Withdrawal({marketParams: idleParams, amount: flow}));
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);
    }

    function testMaxInNoOverflow(uint128 flow) public {
        flow = uint128(bound(flow, 1, CAP2));

        // Set flow limits with withdraw market's maxIn to max
        flowCaps.push(
            FlowCapsConfig({
                id: idleParams.id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: MAX_SETTABLE_FLOW_CAP})
            })
        );
        flowCaps.push(
            FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: 0})})
        );
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        withdrawals.push(Withdrawal({marketParams: idleParams, amount: flow}));
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);
    }

    function testReallocationReallocates(uint128 flow) public {
        flow = uint128(bound(flow, 1, CAP2));

        // Set flow limits
        flowCaps.push(
            FlowCapsConfig({
                id: idleParams.id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: MAX_SETTABLE_FLOW_CAP})
            })
        );
        flowCaps.push(
            FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: 0})})
        );
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        uint256 idleBefore = morpho.expectedSupplyAssets(idleParams, address(vault));
        uint256 marketBefore = morpho.expectedSupplyAssets(allMarkets[0], address(vault));
        withdrawals.push(Withdrawal({marketParams: idleParams, amount: flow}));
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);
        uint256 idleAfter = morpho.expectedSupplyAssets(idleParams, address(vault));
        uint256 marketAfter = morpho.expectedSupplyAssets(allMarkets[0], address(vault));

        assertEq(idleBefore - idleAfter, flow);
        assertEq(marketAfter - marketBefore, flow);
    }

    function testDuplicateInWithdrawals() public {
        // Set flow limits
        flowCaps.push(
            FlowCapsConfig({
                id: idleParams.id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: MAX_SETTABLE_FLOW_CAP})
            })
        );
        flowCaps.push(
            FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: 0})})
        );
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        // Prepare public reallocation from 2 markets to 1
        // _setCap(allMarkets[1], CAP2);
        withdrawals.push(Withdrawal({marketParams: idleParams, amount: 1e18}));
        withdrawals.push(Withdrawal({marketParams: idleParams, amount: 1e18}));
        vm.expectRevert(ErrorsLib.InconsistentWithdrawals.selector);
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);
    }

    function testSupplyMarketInWithdrawals() public {
        // Set flow limits
        flowCaps.push(
            FlowCapsConfig({
                id: idleParams.id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: MAX_SETTABLE_FLOW_CAP})
            })
        );
        flowCaps.push(
            FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: 0})})
        );
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        withdrawals.push(Withdrawal({marketParams: idleParams, amount: 1e18}));
        vm.expectRevert(ErrorsLib.DepositMarketInWithdrawals.selector);
        publicAllocator.reallocateTo(address(vault), withdrawals, idleParams);
    }

    function testReallocateMarketNotEnabledWithdrawn(MarketParams memory marketParams) public {
        vm.assume(!vault.config(marketParams.id()).enabled);

        withdrawals.push(Withdrawal({marketParams: marketParams, amount: 1e18}));

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.MarketNotEnabled.selector, marketParams.id()));
        publicAllocator.reallocateTo(address(vault), withdrawals, idleParams);
    }

    function testReallocateMarketNotEnabledSupply(MarketParams memory marketParams) public {
        vm.assume(!vault.config(marketParams.id()).enabled);

        withdrawals.push(Withdrawal({marketParams: idleParams, amount: 1e18}));

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.MarketNotEnabled.selector, marketParams.id()));
        publicAllocator.reallocateTo(address(vault), withdrawals, marketParams);
    }

    function testReallocateWithdrawZero() public {
        withdrawals.push(Withdrawal({marketParams: idleParams, amount: 0}));

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.WithdrawZero.selector, idleParams.id()));
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);
    }

    function testReallocateEmptyWithdrawals() public {
        vm.expectRevert(ErrorsLib.EmptyWithdrawals.selector);
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);
    }

    function testMaxFlowCapValue() public {
        assertEq(MAX_SETTABLE_FLOW_CAP, 170141183460469231731687303715884105727);
    }

    function testMaxFlowCapLimit(uint128 cap) public {
        cap = uint128(bound(cap, MAX_SETTABLE_FLOW_CAP + 1, type(uint128).max));

        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: 0, maxOut: cap})}));

        vm.expectRevert(ErrorsLib.MaxSettableFlowCapExceeded.selector);
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        delete flowCaps;
        flowCaps.push(FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: cap, maxOut: 0})}));

        vm.expectRevert(ErrorsLib.MaxSettableFlowCapExceeded.selector);
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);
    }

    function testSetFlowCapsMarketNotEnabled(Id id, uint128 maxIn, uint128 maxOut) public {
        vm.assume(!vault.config(id).enabled);
        vm.assume(maxIn != 0 || maxOut != 0);

        flowCaps.push(FlowCapsConfig({id: id, caps: FlowCaps({maxIn: maxIn, maxOut: maxOut})}));

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.MarketNotEnabled.selector, id));
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);
    }

    function testSetFlowCapsToZeroForMarketNotEnabled(Id id) public {
        vm.assume(!vault.config(id).enabled);

        flowCaps.push(FlowCapsConfig({id: id, caps: FlowCaps({maxIn: 0, maxOut: 0})}));

        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        assertEq(publicAllocator.flowCaps(address(vault), id).maxIn, 0);
        assertEq(publicAllocator.flowCaps(address(vault), id).maxOut, 0);
    }

    function testNotEnoughSupply() public {
        uint128 flow = 1e18;
        // Set flow limits with withdraw market's maxIn to max
        flowCaps.push(
            FlowCapsConfig({
                id: idleParams.id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: MAX_SETTABLE_FLOW_CAP})
            })
        );
        flowCaps.push(
            FlowCapsConfig({
                id: allMarkets[0].id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: MAX_SETTABLE_FLOW_CAP})
            })
        );
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        withdrawals.push(Withdrawal({marketParams: idleParams, amount: flow}));
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);

        delete withdrawals;

        withdrawals.push(Withdrawal({marketParams: allMarkets[0], amount: flow + 1}));
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotEnoughSupply.selector, allMarkets[0].id()));
        publicAllocator.reallocateTo(address(vault), withdrawals, idleParams);
    }

    function testMaxOutflowExceeded() public {
        uint128 cap = 1e18;
        // Set flow limits with withdraw market's maxIn to max
        flowCaps.push(
            FlowCapsConfig({id: idleParams.id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: cap})})
        );
        flowCaps.push(
            FlowCapsConfig({
                id: allMarkets[0].id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: MAX_SETTABLE_FLOW_CAP})
            })
        );
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        withdrawals.push(Withdrawal({marketParams: idleParams, amount: cap + 1}));
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.MaxOutflowExceeded.selector, idleParams.id()));
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);
    }

    function testMaxInflowExceeded() public {
        uint128 cap = 1e18;
        // Set flow limits with withdraw market's maxIn to max
        flowCaps.push(
            FlowCapsConfig({
                id: idleParams.id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: MAX_SETTABLE_FLOW_CAP})
            })
        );
        flowCaps.push(
            FlowCapsConfig({id: allMarkets[0].id(), caps: FlowCaps({maxIn: cap, maxOut: MAX_SETTABLE_FLOW_CAP})})
        );
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        withdrawals.push(Withdrawal({marketParams: idleParams, amount: cap + 1}));
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.MaxInflowExceeded.selector, allMarkets[0].id()));
        publicAllocator.reallocateTo(address(vault), withdrawals, allMarkets[0]);
    }

    function testReallocateToNotSorted() public {
        // Prepare public reallocation from 2 markets to 1
        _setCap(allMarkets[1], CAP2);

        MarketAllocation[] memory allocations = new MarketAllocation[](3);
        allocations[0] = MarketAllocation({marketParams: idleParams, assets: INITIAL_DEPOSIT - 2e18});
        allocations[1] = MarketAllocation({marketParams: allMarkets[0], assets: 1e18});
        allocations[2] = MarketAllocation({marketParams: allMarkets[1], assets: 1e18});
        vm.prank(OWNER);
        vault.reallocate(allocations);

        flowCaps.push(
            FlowCapsConfig({
                id: idleParams.id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: MAX_SETTABLE_FLOW_CAP})
            })
        );
        flowCaps.push(
            FlowCapsConfig({
                id: allMarkets[0].id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: MAX_SETTABLE_FLOW_CAP})
            })
        );
        flowCaps.push(
            FlowCapsConfig({
                id: allMarkets[1].id(), caps: FlowCaps({maxIn: MAX_SETTABLE_FLOW_CAP, maxOut: MAX_SETTABLE_FLOW_CAP})
            })
        );
        vm.prank(OWNER);
        publicAllocator.setFlowCaps(address(vault), flowCaps);

        withdrawals.push(Withdrawal({marketParams: allMarkets[0], amount: 1e18}));
        withdrawals.push(Withdrawal({marketParams: allMarkets[1], amount: 1e18}));
        Withdrawal[] memory sortedWithdrawals = withdrawals.sort();
        // Created non-sorted withdrawals list
        withdrawals[0] = sortedWithdrawals[1];
        withdrawals[1] = sortedWithdrawals[0];

        vm.expectRevert(ErrorsLib.InconsistentWithdrawals.selector);
        publicAllocator.reallocateTo(address(vault), withdrawals, idleParams);
    }
}
