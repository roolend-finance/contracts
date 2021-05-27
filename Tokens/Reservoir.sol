pragma solidity ^0.5.16;

import "../Comptroller/ComptrollerInterface.sol";
import "../Math/SafeMath.sol";
import "../Controller/Controller.sol";
import "../ROO/ROO.sol";

contract Reservoir is Controller {
    using SafeMath for uint256;
    ComptrollerInterface public comptroller;

    uint256 fundLastRewardBlock;

    // maybe change the block.timestamp policy to determine the duration between calls

    // 按照3秒出一个区块计算，即86400/3，若OK正式链出块时间不是3秒，则需要重新计算
    uint256 constant DAY = 28800;
    uint256 PER30DAYS = 30 * DAY;
    uint256 constant MINUTES = 20; // 60 seconds / 3 = 20 blocks

    uint256 constant MAX_RATE = 1e18;
    // 每块最小出币数量
    uint256 constant MIN_ROO_PER_BLOCK = 0.2 * 1e18;
    bool isFunded = false;
    // 团队奖励10%
    uint256 constant TEAM_FUND_DIV_RATE = 7e16;
    uint256 constant INVESTOR_DIV_RATE = 3e16;
    uint256 constant INVESTOR_INIT_FUND_RATIO = 15e16;
    address investorAddr = address(0xF663d68Be3D62697C97583E672b79278a7d0758c);
    uint256 fundLastBlockForInvestor;
    // 风险基金5%
    uint256 constant INSURANCE_FUND_DIV_RATE = 5e16;
    // 市场运营推广5%
    uint256 constant MARKETS_FUND_DIV_RATE = 4e16;
    uint256 constant MARKETS_FUND_INIT_DIV_RATE = 1e16;
    // 流动性挖矿80%
    uint256 constant LIQUIDITY_FUND_DIV_RATE = 80e16;

    uint256 COMPTROLLER_DURATION = MINUTES;

    ROO public rewardToken;

    // 当前每块出币数量
    uint256 public tokenPerBlock = 2e18;
    // 每块用于流动性挖矿奖励的数量
    uint256 public tokenPerBlockForReward;

    address teamAddr;
    address marketAddr;
    address insuranceAddr;

    uint256 decrement = 0;

    uint256 public startBlock;
    uint256 public periodEndBlock;
    uint256 public comptrollerLastReward;

    uint256 public duration;

    // Events
    event Recovered(address token, uint256 amount);

    enum RecipientType {
        TEAM, // Team type for share the funds
        INSURANCE, // insurance type for share the funds
        MARKETS, // markets type for share the funds
        LIQUIDITY // liquidity type for share the funds
    }

    /**
     * event for distributed the reward
     * @param distributed_to See ZombieType
     * @param mount The mount of the rewards to share for this distributed_to
     * @param totalBlocks the blocks passed when received claimFund
     * @param tokenPerBlock the token per blocks
     */
    event DestributedRewards(
        RecipientType distributed_to,
        uint256 mount,
        uint256 totalBlocks,
        uint256 tokenPerBlock
    );

    /**
     * event for test
     * @param message log message for this event
     */
    event LogMessage(string message);

    constructor(
        ROO _rewardToken,
        uint256 _startBlock,
        uint256 _duration
    ) public Controller() {
        if (_startBlock == 0) {
            _startBlock = block.number;
        }

        if (_duration == 0) {
            _duration = PER30DAYS;
        }

        periodEndBlock = _startBlock.add(_duration);
        require(periodEndBlock > block.number, "endding was wrong");
        rewardToken = _rewardToken;
        startBlock = _startBlock;
        fundLastRewardBlock = _startBlock;
        fundLastBlockForInvestor = _startBlock;
        duration = _duration;
    }

    /**
        @notice 启动代币挖矿，将代币一次性转入到该合约中做管理
     */
    function mintToken() public onlyOwner {
        rewardToken.mint(address(this));
    }

    modifier adjustProduct() {
        if (block.number < startBlock) {
            emit LogMessage("block number is smaller than start block, when adjust product");
            return;
        }

        if (block.number >= periodEndBlock) {
            if (tokenPerBlock > MIN_ROO_PER_BLOCK) {
                tokenPerBlock = tokenPerBlock.mul(91).div(100); // 每30天减产9%
            }

            if (tokenPerBlock < MIN_ROO_PER_BLOCK) {
                tokenPerBlock = MIN_ROO_PER_BLOCK; // 如果小于0.2 * 1e18则不继续减少
            }

            periodEndBlock = block.number.add(duration);
        }

        if (comptrollerLastReward < block.number) {
            uint256 _reward = duration.mul(tokenPerBlock);
            uint256 liquidityFund = calRate(_reward, LIQUIDITY_FUND_DIV_RATE);
            if (address(comptroller) != address(0)) {
                safeTokenTransfer(address(comptroller), liquidityFund);
                ComptrollerInterface(comptroller)._setCompRate(calRate(tokenPerBlock, LIQUIDITY_FUND_DIV_RATE));
                comptrollerLastReward = block.number.add(duration);
                emit DestributedRewards(
                    RecipientType.LIQUIDITY,
                    liquidityFund,
                    duration,
                    tokenPerBlock
                );
            }
        }
        _;
    }

    /**
        @notice 计算分配比例
     */
    function calRate(uint256 _amount, uint256 rate) public pure returns (uint256) {
        return _amount.mul(rate).div(1e18);
    }

    /**
        @notice 分发流动性挖矿奖励代币
     */
    function distributeRewardToken() adjustProduct internal {
        // nothing to do
    }

    // Safe pickle transfer function, just in case if rounding error causes pool to not have enough dex.
    function safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 pickleBal = rewardToken.balanceOf(address(this));
        if (_amount > pickleBal) {
            rewardToken.transfer(_to, pickleBal);
        } else {
            rewardToken.transfer(_to, _amount);
        }
    }

    function _setTeamAddr(address account) public onlyController {
        teamAddr = account;
    }

    function _setMarketAddr(address account) public onlyController {
        marketAddr = account;
    }

    function _setInsuranceAddr(address account) public onlyController {
        insuranceAddr = account;
    }

    function claimFundForMarketAndInvestors() public {
        require(!isFunded, "funded");
        uint256 pickleBal = rewardToken.balanceOf(address(this));
        uint256 marketFund = calRate(rewardToken.totalSupply(), MARKETS_FUND_INIT_DIV_RATE);
        uint256 investorFundIndex = calRate(INVESTOR_DIV_RATE, INVESTOR_INIT_FUND_RATIO);
        uint256 investorFund = calRate(rewardToken.totalSupply(), investorFundIndex);
        uint256 totalFund = marketFund.add(investorFund);
        require(pickleBal >= totalFund, "pickleBal < totalFund");
        isFunded = true;
        rewardToken.transfer(investorAddr, totalFund);
    }

    function claimFundForInvestor() public {
        uint256 nextRewardBlock = fundLastBlockForInvestor.add(PER30DAYS);
        require (block.number >= nextRewardBlock, "current block is smaller than next reward block");
        uint256 totalAmount = calRate(rewardToken.totalSupply(), INVESTOR_DIV_RATE);
        uint256 initInvestorAmount = calRate(totalAmount, INVESTOR_INIT_FUND_RATIO);
        uint256 amount = totalAmount.sub(initInvestorAmount).div(12);
        uint256 pickleBal = rewardToken.balanceOf(address(this));
        require(pickleBal >= amount, "pickleBal < totalFund");
        rewardToken.transfer(investorAddr, amount);
        fundLastBlockForInvestor = nextRewardBlock;
    }

    /**
        @notice 分发流动性挖矿奖励
     */
    function claimFund() external onlyController {
        require(marketAddr != address(0), "invalid market address");
        require(insuranceAddr != address(0), "invalid insurance address");
        require(teamAddr != address(0), "invalid team address");

        if (block.number <= fundLastRewardBlock) {
            emit LogMessage("current block is smaller or equal to start block");
            return;
        }

        // why not match the policy of the decrease ???
        uint256 multiplier = block.number - fundLastRewardBlock;

        // get total reward in past block according the tokenPerBlock
        uint256 boxReward = multiplier.mul(tokenPerBlock);

        // calculate the markets rewards according to the MARKETS_FUND_DIV_RATE
        uint256 marketFund = calRate(boxReward, MARKETS_FUND_DIV_RATE);
        // calculate the insurance rewards accoding to the INSURANCE_FUND_DIV_RATE
        uint256 insuranceFund = calRate(boxReward, INSURANCE_FUND_DIV_RATE);
        // calculate the team rewards according to the TEAM_FUND_DIV_RATE
        uint256 teamFund = calRate(boxReward, TEAM_FUND_DIV_RATE);
        // calculate the liquidity rewards according to the LIQUIDITY_FUND_DIV_RATE
        // uint256 liquidityFund = calRate(boxReward, LIQUIDITY_FUND_DIV_RATE);

        // transfer token to market
        safeTokenTransfer(marketAddr, marketFund);
        emit DestributedRewards(
            RecipientType.MARKETS,
            marketFund,
            multiplier,
            tokenPerBlock
        );

        // transfer token to insurance
        safeTokenTransfer(insuranceAddr, insuranceFund);
        emit DestributedRewards(
            RecipientType.INSURANCE,
            insuranceFund,
            multiplier,
            tokenPerBlock
        );

        // transfer token to team
        safeTokenTransfer(teamAddr, teamFund);
        emit DestributedRewards(
            RecipientType.TEAM,
            teamFund,
            multiplier,
            tokenPerBlock
        );

        distributeRewardToken();

        fundLastRewardBlock = block.number;
    }

    function _setComptroller(address _address) external onlyController {
        comptroller = ComptrollerInterface(_address);
    }
}
