// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {AggregatorV3Interface} from "@chainlink/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Test, console} from "forge-std/Test.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";
import {SeeseaToken} from "../src/Token.sol";
import {Staking} from "src/Staking.sol";

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                        STAKING TEST                        */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

contract StakingTest is Test {
    Staking public staking;
    uint256 public amount;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       STAKING CONFIG                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    uint256 public duration;
    uint256 public rewardPoints;
    uint256 public stakingProgramEndsBlock;
    uint256 public stakingFundAmount;
    uint256 public rewardTokenAmount;
    uint256 public vestingDuration;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ASSETS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    DummyERC20 public rewardToken;
    DummyERC20 public poolToken;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ACTORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    address public owner;
    address public recipient;
    address public recipient2;

    address stakingFund;

    modifier prank(address who) {
        vm.startPrank(who);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        owner = makeAddr("owner");
        recipient = makeAddr("recipient");
        recipient2 = makeAddr("recipient2");

        vm.startPrank(owner);
        rewardToken = new DummyERC20("REWARD", "REWARD", 18);
        poolToken = new DummyERC20("POOL", "POOL", 18);

        vm.label(address(poolToken), "Pool Token");
        vm.label(address(rewardToken), "Reward Token");

        stakingFundAmount = 1_000_000;
        stakingProgramEndsBlock = 7 days;
        vestingDuration = 7 days;

        stakingFund = makeAddr("stakingFund");

        poolToken.mint(stakingFund, stakingFundAmount);
        rewardToken.mint(stakingFund, stakingFundAmount);

        poolToken.mint(recipient, 1_000_000);

        rewardToken.approve(stakingFund, type(uint256).max);

        staking =
            new Staking(address(rewardToken), stakingProgramEndsBlock, stakingFundAmount, vestingDuration, owner, 1);

        console.log("Staking contract deployed at", address(staking));

        vm.stopPrank();

        vm.prank(stakingFund);
        rewardToken.approve(address(staking), type(uint256).max);

        vm.prank(owner);
        staking.setPoolToken(address(poolToken), stakingFund);
    }

    function test_owner_address_is_set_correctly_during_contract_deployement() public {
        assertEq(staking.owner(), owner);
    }

    function test_lock_tokens_successfully_when_pool_is_set() public prank(recipient) {
        uint72 tokenAmount = 1000;
        uint16 lockingPeriodInDays = 30;
        poolToken.approve(address(staking), type(uint256).max);
        staking.lockTokens(tokenAmount, lockingPeriodInDays);

        // check on state afterwards.
        assertLt(poolToken.balanceOf(recipient), 1_000_000);
    }

    function test_lock_token_when_pool_is_set_with_zero_amount_fails() public prank(recipient) {
        uint72 tokenAmount = 0;
        uint16 lockingPeriodInDays = 30;
        poolToken.approve(address(staking), type(uint256).max);

        vm.expectRevert("Neither tokenAmount nor lockingPeriod couldn't be 0");
        staking.lockTokens(tokenAmount, lockingPeriodInDays);
    }

    function test_unlock_tokens_after_locking_period_ends() public prank(recipient) {
        uint72 tokenAmount = 1000;
        uint16 lockingPeriodInDays = 30;

        poolToken.approve(address(staking), type(uint256).max);

        staking.lockTokens(tokenAmount, lockingPeriodInDays);

        vm.roll(block.number + lockingPeriodInDays);
        staking.unlockTokens();
        assertEq(poolToken.balanceOf(recipient), 1_000_000);
    }

    function test_unlock_tokens_in_same_block_fails() public prank(recipient) {
        uint72 tokenAmount = 1000;
        uint16 lockingPeriodInDays = 30;

        poolToken.approve(address(staking), type(uint256).max);

        staking.lockTokens(tokenAmount, lockingPeriodInDays);

        vm.expectRevert("You can't withdraw the stake in the same block it was locked");
        staking.unlockTokens();
    }

    function test_unlock_tokens_before_locking_period_ends() public prank(recipient) {
        uint72 tokenAmount = 1000;
        uint16 lockingPeriodInDays = 30;

        poolToken.approve(address(staking), type(uint256).max);

        staking.lockTokens(tokenAmount, lockingPeriodInDays);

        vm.roll(block.number + lockingPeriodInDays);
        // vm.roll(block.number + 1);
        staking.unlockTokens();
        console.log(poolToken.balanceOf(recipient));
    }

    function test_calculate_staking_reward_correctly() public {
        uint72 tokenAmount = 1000;
        uint24 lockingPeriod = 30;

        uint128 expectedStakingRewardPoints = staking.calculateStakingRewardPoints(tokenAmount, lockingPeriod);

        assertEq(expectedStakingRewardPoints, 82);
    }

    function test_get_rewards_after_staking_ends_with_no_reward_points() public prank(recipient) {
        vm.roll(block.number + vestingDuration + stakingProgramEndsBlock);
        vm.expectRevert("You can only get Rewards after Staking Program ends");
        staking.getRewards();
    }

    function test_get_rewards_before_staking_ends_with_no_stake_locked() public prank(recipient) {
        vm.expectRevert("You can only get Rewards after Staking Program ends");
        staking.getRewards();
    }

    function test_release_vested_tokens_after_vesting_duration_ends_fails() public prank(recipient) {
        uint72 tokenAmount = 1000;
        uint16 lockingPeriodInDays = 30;

        poolToken.approve(address(staking), type(uint256).max);
        staking.lockTokens(tokenAmount, lockingPeriodInDays);

        vm.roll(vestingDuration + stakingProgramEndsBlock);

        // fails as no rewards available
        vm.expectRevert("Reward not available yet");
        staking.release();
    }

    function test_release_vested_tokens_after_vesting_duration_ends() public prank(recipient) {
        uint72 tokenAmount = 1000;
        uint16 lockingPeriodInDays = 30;

        poolToken.approve(address(staking), type(uint256).max);
        staking.lockTokens(tokenAmount, lockingPeriodInDays);

        vm.roll(vestingDuration + stakingProgramEndsBlock + 10);

        // fails as no rewards available
        vm.expectRevert("Reward not available yet");
        staking.release();
    }

    function test_set_pool_token_again_fails() public prank(owner) {
        vm.expectRevert("poolToken was already set");
        staking.setPoolToken(address(poolToken), stakingFund);
    }

    function test_early_withdrawal_punishment() public prank(recipient) {
        uint72 tokenAmount = 1000;
        uint16 lockingPeriodInDays = 30;

        poolToken.approve(address(staking), type(uint256).max);
        staking.lockTokens(tokenAmount, lockingPeriodInDays);

        console.log("b4 bn", block.number);
        vm.roll(block.number + 2);
        console.log("2 days later?", block.number);

        staking.unlockTokens();
    }

    function test_attempts_to_lock_tokens_when_already_staking() public prank(recipient) {
        uint72 tokenAmount = 1000;
        uint16 lockingPeriodInDays = 30;
        uint72 tokenAmount2 = 1000;
        poolToken.approve(address(staking), type(uint256).max);
        staking.lockTokens(tokenAmount, lockingPeriodInDays);
        vm.expectRevert("Already staking");
        staking.lockTokens(tokenAmount2, lockingPeriodInDays);
    }
}

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                         TOKEN TEST                         */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

contract MockUSDTBNBAggregator is AggregatorV3Interface {
    int256 public answer;

    constructor(int256 _answer) {
        answer = _answer;
    }

    function decimals() external view override returns (uint8) {
        return 18;
    }

    function description() external view override returns (string memory) {
        return "MockETHLINKAggregator";
    }

    function version() external view override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 ans, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, answer, block.timestamp, block.timestamp, 1);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 ans, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, answer, block.timestamp, block.timestamp, 1);
    }
}

contract MockBNBUSDTAggregator is AggregatorV3Interface {
    int256 public answer;

    constructor(int256 _answer) {
        answer = _answer;
    }

    function decimals() external view override returns (uint8) {
        return 18;
    }

    function description() external view override returns (string memory) {
        return "MockETHLINKAggregator";
    }

    function version() external view override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 ans, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, answer, block.timestamp, block.timestamp, 1);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 ans, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, answer, block.timestamp, block.timestamp, 1);
    }
}

contract TokenTest is Test {
    SeeseaToken poolToken;
    MockBNBUSDTAggregator bnbusdtfeed;
    MockUSDTBNBAggregator usdtbnbfeed;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ACTORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    address public owner;
    address public recipient;

    DummyERC20 usdt;
    DummyERC20 usdc;

    modifier prank(address who) {
        vm.startPrank(who);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        vm.createSelectFork("bsc");

        owner = makeAddr("owner");
        recipient = makeAddr("recipient");

        bnbusdtfeed = new MockBNBUSDTAggregator(1);
        usdtbnbfeed = new MockUSDTBNBAggregator(1);

        usdt = new DummyERC20("usdt", "usdt", type(uint16).max);
        usdc = new DummyERC20("usdc", "usdc", type(uint16).max);

        vm.label(address(usdt), "usdt");
        vm.label(address(usdc), "usdc");

        usdc.mint(owner, type(uint8).max);
        usdc.mint(recipient, type(uint8).max);

        vm.deal(owner, 100 ether);

        vm.startPrank(owner);
        poolToken = new SeeseaToken(owner, address(bnbusdtfeed), address(usdtbnbfeed), address(usdc), address(usdt));

        vm.label(address(poolToken), "POOL TOKEN");

        poolToken.approve(owner, type(uint256).max);

        console.log("Token contract deployed at", address(poolToken));
        vm.stopPrank();
    }

    function test_uni_router() public prank(recipient) {
        assertEq(address(poolToken.uniswapV2Router()), address(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F));
    }

    function test_call_uni_pair() public prank(recipient) {
        assertEq(address(poolToken.uniswapV2Pair()), address(0x70641dC17C5997fE03A93d2F06429D58AC037006));
    }

    function test_expected_tax_fee_set() public prank(recipient) {
        assertEq(poolToken._taxFee(), 5);
    }

    function test_owner_can_pause_the_contract() public prank(owner) {
        vm.deal(owner, 1 ether);
        poolToken.pause();

        vm.expectRevert();
        poolToken.buyTokensBNB{value: 1 ether}();
    }

    function test_owner_can_unpause_the_contract() public {
        test_owner_can_pause_the_contract();
        vm.prank(owner);
        poolToken.unpause();
        assertEq(poolToken.paused(), false);
    }

    function test_setting_tax_fee_percentage() public prank(owner) {
        poolToken.setTaxFeePercent(10);
        assertEq(poolToken._taxFee(), 10);
    }

    function test_withdraw_tokens_by_owner() public prank(owner) {
        poolToken.withdrawTokens(0, address(usdc));
        assertEq(usdc.balanceOf(address(poolToken)), 0);
    }

    function test_buying_tokens_with_bnb() public prank(recipient) {
        deal(recipient, 1 ether);
        poolToken.buyTokensBNB{value: 1}();
        assertGt(poolToken.balanceOf(recipient), 0);
    }

    function test_attempting_to_buy_with_unsupported_token(uint256 buyAmount) public prank(recipient) {
        bound(buyAmount, 1, 50);
        vm.expectRevert("token is not supported");
        poolToken.buyTokens(address(1), buyAmount);
    }

    function test_buying_tokens_with_supported_tokens(uint8 buyAmount) public prank(recipient) {
        usdc.approve(address(poolToken), type(uint256).max);
        poolToken.buyTokens(address(usdc), 1);
        assertGt(poolToken.balanceOf(recipient), 0);
    }
}
