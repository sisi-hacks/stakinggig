// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";

/// @title staking contract
/// @author sisi-hacks
/// @dev that staking contract is fully dependent on the provided reward token and the underlying LP token.

contract Staking is ReentrancyGuard {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    event StakeLocked(
        address recipient, uint256 tokenAmount, uint256 lockingPeriodIn, uint256 expectedStakingRewardPoints
    );
    event StakeUnlockedPrematurely(
        address recipient, uint256 tokenAmount, uint256 lockingPeriodIn, uint256 actualLockingPeriodIn
    );
    event StakeUnlocked(address recipient, uint256 tokenAmount, uint256 lockingPeriodIn, uint256 rewardPoints);
    event RewardGranted(address recipient, uint256 amountEarned);
    event grantedTokensReleased(address recipient, uint256 amount);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    struct Stake {
        uint72 tokenAmount; // Amount of tokens locked in a stake
        uint24 lockingPeriodIn; // Arbitrary lock period that will give you a reward
        uint32 startBlock; // Start of the locking
        uint128 expectedStakingRewardPoints; // The amount of RewardPoints the stake will earn if not unlocked prematurely
    }

    using SafeERC20 for IERC20;

    /// @notice Active stakes for each user
    mapping(address => Stake) public stakes;

    /// @notice "Reward points" each user earned (would be relative to totalRewardPoints to get the percentage)
    mapping(address => uint256) public rewardPointsEarned;

    /// @notice Total "reward points" all users earned
    uint256 public totalRewardPoints;
    /// @notice when Staking Program ends
    uint256 public immutable stakingProgramEnds;
    /// @notice Amount of Staking Bonus Fund (500 000 REWARD), reward funds must be here, approved and ready to be transferredFrom
    uint256 public immutable stakingFundAmount;
    uint256 public immutable annualYieldRate;

    /// @notice Uniswap pool that we accept LP tokens from
    IERC20 public poolToken;
    /// @notice Reward token that will be given as a reward
    IERC20 public immutable rewardToken;

    /// @notice The amount of REWARD tokens earned, granted to be released during vesting period
    mapping(address => uint256) public grantedTokens;
    /// @notice The amount of REWARD tokens that were already released during vesting period
    mapping(address => uint256) public releasedTokens;

    /// @dev should be around 7 days
    uint256 public immutable vestingDuration;

    /// @dev Check if poolToken was initialized
    modifier poolTokenSet() {
        require(address(poolToken) != address(0), "poolToken not set");
        _;
    }

    /// @dev Owner is used only in setPoolToken()
    address public immutable owner;

    /// @dev Used only in setPoolToken()
    modifier onlyOwner() {
        require(msg.sender == owner, "Can only be called by owner");
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev before deploying the stakingFundAddress must have set allowances on behalf of that contract. The address can be predicted basing on the CREATE or CREATE2 opcode.
     * @param rewardToken_ - address of the token in which rewards will be payed off.
     * @param stakingDurationIn_ - Time after which staking will end.
     * @param stakingFundAmount_ - Amount of tokens to be payed of as rewards.
     * @param vestingDuration_ - Time after which REWARD tokens earned by staking will be released (duration of Vesting period).
     * @param owner_ - Owner of the contract (is used to initialize poolToken after it's available).
     */
    constructor(
        address rewardToken_,
        uint256 stakingDurationIn_,
        uint256 stakingFundAmount_,
        uint256 vestingDuration_,
        address owner_,
        uint256 annualYieldRate_
    ) {
        require(owner_ != address(0), "Owner address cannot be zero");
        owner = owner_;

        require(rewardToken_ != address(0), "rewardToken address cannot be zero");
        rewardToken = IERC20(rewardToken_);

        stakingProgramEnds = block.timestamp + stakingDurationIn_;
        vestingDuration = vestingDuration_;

        stakingFundAmount = stakingFundAmount_;
        annualYieldRate = annualYieldRate_;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              PUBLIC / EXTERNAL VIEW FUNCTIONS              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Calculates the RewardPoints user will earn for a given tokenAmount locked for a given period
     * @dev If any parameter is zero - it will fail, thus we save gas on "requires" by not checking in other places
     * @param tokenAmount_ - Amount of tokens to be stake.
     * @param lockingPeriodIn_ - Lock duration.
     */
    function calculateStakingRewardPoints(uint72 tokenAmount_, uint24 lockingPeriodIn) public pure returns (uint128) {
        uint256 stakingRewardPoints = (tokenAmount_ * annualYieldRate * lockingPeriodIn) / 365;
        require(stakingRewardPoints > 0, "Neither tokenAmount nor lockingPeriod couldn't be 0");
        return uint128(stakingRewardPoints);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              PUBLIC / EXTERNAL WRITE FUNCTIONS             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Lock the LP tokens for a specified period of Time.
     * @notice Can only be called before Staking Program ends.
     * @notice And the locking period can't last longer than the end of Staking Program .
     * @param tokenAmount_ - Amount of LP tokens to be locked.
     * @param lockingPeriodIn_ - locking period duration.
     */
    function lockTokens(uint72 tokenAmount_, uint24 lockingPeriodIn_) public poolTokenSet nonReentrant {
        require(block.timestamp <= stakingProgramEnds, "Staking Program has ended");
        require(lockingPeriodIn_ > 0, "Locking period cannot be zero");
        // Convert to days for easier handling of staking limits and calculations
        uint256 lockingPeriodInDays = lockingPeriodIn_ / 86_400;

        // Here we don't check lockingPeriodIn_ for being non-zero, cause its happening in calculateStakingRewardPoints() calculation
        require(
            block.timestamp <= stakingProgramEnds - lockingPeriodIn_,
            "Your lock period exceeds Staking Program duration"
        );
        require(stakes[msg.sender].tokenAmount == 0, "Already staking");

        // Check staking limits based on the locking period in days
        if (lockingPeriodInDays >= 30 && lockingPeriodInDays <= 60) {
            require(tokenAmount_ <= 10_000, "Exceeds 30-60 days staking limit of 10,000 tokens");
        } else if (lockingPeriodInDays == 90) {
            require(tokenAmount_ <= 10_000, "Exceeds 90 days staking limit of 10,000 tokens");
        } else if (lockingPeriodInDays == 180 || lockingPeriodInDays == 360) {
            require(tokenAmount_ <= 5000, "Exceeds 180/360 days staking limit of 5,000 tokens");
        } else if (lockingPeriodInDays == 720) {
            require(tokenAmount_ <= 2000, "Exceeds 720 days staking limit of 2,000 tokens");
        } else {
            revert("Invalid locking period");
        }

        // This is a locking reward - will be earned only after the full lock period is over - otherwise not applicable
        uint128 expectedStakingRewardPoints = calculateStakingRewardPoints(tokenAmount_, lockingPeriodIn_);

        Stake memory stake = Stake(tokenAmount_, lockingPeriodIn_, uint32(block.timestamp), expectedStakingRewardPoints);
        stakes[msg.sender] = stake;

        // We add the rewards initially during locking of tokens, and subtract them later if unlocking is made prematurely
        // That prevents us from waiting for all users to unlock to distribute the rewards after Staking Program Ends
        totalRewardPoints += expectedStakingRewardPoints;
        rewardPointsEarned[msg.sender] += expectedStakingRewardPoints;

        // We transfer LP tokens from user to this contract, "locking" them
        // We don't check for allowances or balance cause it's done within the transferFrom() and would only raise gas costs
        (bool success) = poolToken.transferFrom(msg.sender, address(this), tokenAmount_);
        require(success, "TransferFrom of poolTokens failed");

        emit StakeLocked(msg.sender, tokenAmount_, lockingPeriodIn_, expectedStakingRewardPoints);
    }

    /**
     * @notice Unlock the tokens and get the reward
     * @notice This can be called at any time, even after Staking Program end block
     */
    function unlockTokens() public poolTokenSet nonReentrant {
        Stake memory stake = stakes[msg.sender];

        uint256 stakeAmount = stake.tokenAmount;

        require(stakeAmount != 0, "You don't have a stake to unlock");

        require(block.timestamp > stake.startBlock, "You can't withdraw the stake in the same block it was locked");

        // Check if the unlock is called prematurely - and subtract the reward if it is the case
        _punishEarlyWithdrawal(stake);

        // Zero the Stake - to protect from double-unlocking and to be able to stake again
        delete stakes[msg.sender];

        (bool success) = poolToken.transfer(msg.sender, stakeAmount);
        require(success, "Pool token transfer failed");
    }

    /**
     * @notice This can only be called after the Staking Program ended
     * @dev Which means that all stakes lock periods are already over, and totalRewardPoints value isn't changing anymore - so we can now calculate the percentages of rewards
     */
    function getRewards() public {
        require(block.timestamp > stakingProgramEnds, "You can only get Rewards after Staking Program ends");
        require(
            stakes[msg.sender].tokenAmount == 0,
            "You still have a stake locked - please unlock first, don't leave free money here"
        );
        require(rewardPointsEarned[msg.sender] > 0, "You don't have any rewardPoints");

        uint256 amountEarned = stakingFundAmount * rewardPointsEarned[msg.sender] / totalRewardPoints;
        rewardPointsEarned[msg.sender] = 0; // Zero rewardPoints of a user - so this function can be called only once per user

        _grantTokens(msg.sender, amountEarned); // Grant REWARD reward earned by user for future vesting during the Vesting period
    }

    /// @notice Releases granted tokens
    function release() public nonReentrant {
        uint256 releasable = _releasableAmount(msg.sender);
        require(releasable > 0, "Vesting release: no tokens are due");

        releasedTokens[msg.sender] += releasable;
        (bool success) = rewardToken.transfer(msg.sender, releasable);
        require(success, "Reward transfer failed");

        emit grantedTokensReleased(msg.sender, releasable);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   ADMIN WRITE FUNCTIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Initialize poolToken when REWARD<>USDC Uniswap pool is available
    function setPoolToken(address poolToken_, address stakingFundAddress_) public onlyOwner {
        require(address(poolToken) == address(0), "poolToken was already set");
        require(poolToken_ != address(0), "poolToken address cannot be zero");
        poolToken = IERC20(poolToken_);
        // Transfer the Staking Bonus Funds from stakingFundAddress here
        require(
            IERC20(rewardToken).balanceOf(stakingFundAddress_) >= stakingFundAmount,
            "StakingFund doesn't have enough REWARD balance"
        );
        require(
            IERC20(rewardToken).allowance(stakingFundAddress_, address(this)) >= stakingFundAmount,
            "StakingFund doesn't have enough allowance"
        );
        require(
            IERC20(rewardToken).transferFrom(stakingFundAddress_, address(this), stakingFundAmount),
            "TransferFrom of REWARD from StakingFund failed"
        );
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 INTERNAL HELPERS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice If the unlock is called prematurely - we subtract the bonus
     */
    function _punishEarlyWithdrawal(Stake memory stake_) internal {
        // As any of the locking periods can't be longer than Staking Program end  - this will automatically mean that if called after Staking Program end - all stakes locking periods are over
        // So no rewards can be manipulated after Staking Program ends
        if (block.timestamp < (stake_.startBlock + stake_.lockingPeriodIn)) {
            // lt - cause you can only withdraw at or after startBlock + lockPeriod
            rewardPointsEarned[msg.sender] -= stake_.expectedStakingRewardPoints;
            totalRewardPoints -= stake_.expectedStakingRewardPoints;
            emit StakeUnlockedPrematurely(
                msg.sender, stake_.tokenAmount, stake_.lockingPeriodIn, block.timestamp - stake_.startBlock
            );
        } else {
            emit StakeUnlocked(
                msg.sender, stake_.tokenAmount, stake_.lockingPeriodIn, stake_.expectedStakingRewardPoints
            );
        }
    }

    /**
     * @param recipient_ - Recipient of granted tokens
     * @param amountEarned_ - Amount of tokens earned to be granted
     */
    function _grantTokens(address recipient_, uint256 amountEarned_) internal {
        require(amountEarned_ > 0, "You didn't earn any integer amount of wei");
        require(recipient_ != address(0), "TokenVesting: beneficiary is the zero address");
        grantedTokens[recipient_] = amountEarned_;
        emit RewardGranted(recipient_, amountEarned_);
    }

    /// @notice Releasable amount is what is available at a given time minus what was already withdrawn
    function _releasableAmount(address recipient_) internal view returns (uint256) {
        return _vestedAmount(recipient_) - releasedTokens[recipient_];
    }

    /**
     * @notice The output of this function gradually changes from [0.. to ..grantedAmount] while the vesting is going
     * @param recipient_ - vested tokens recipient
     * @return vested amount
     */
    function _vestedAmount(address recipient_) internal view returns (uint256) {
        if (block.timestamp >= stakingProgramEnds + vestingDuration) {
            // Return the full granted amount if Vesting Period is over
            return grantedTokens[recipient_];
        } else {
            // Return the proportional amount if Vesting Period is still going
            return grantedTokens[recipient_] * (block.timestamp - stakingProgramEnds) / vestingDuration;
        }
    }
}
