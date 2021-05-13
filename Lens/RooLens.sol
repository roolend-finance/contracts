pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "../Tokens/RErc20.sol";
import "../PriceOracle/PriceOracle.sol";
import "../Governance/GovernorAlpha.sol";
import "../Tokens/RToken.sol";
import "../Tokens/ERC20NonStandardInterface.sol";
import "../Okexchain/ROO.sol";

interface ComptrollerLensInterface {
    function markets(address) external view returns (bool, uint);
    function oracle() external view returns (PriceOracle);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
    function getAssetsIn(address) external view returns (RToken[] memory);
    function claimComp(address) external;
    function compAccrued(address) external view returns (uint);
}

contract RoolendLens {
    struct RTokenMetadata {
        address cToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint cTokenDecimals;
        uint underlyingDecimals;
    }

    function cTokenMetadata(RToken rToken) public returns (RTokenMetadata memory) {
        uint exchangeRateCurrent = rToken.exchangeRateCurrent();
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(rToken.comptroller()));
        (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(rToken));
        address underlyingAssetAddress;
        uint underlyingDecimals;

        if (compareStrings(rToken.symbol(), "cETH")) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            RErc20 cErc20 = RErc20(address(rToken));
            underlyingAssetAddress = cErc20.underlying();
            underlyingDecimals = ERC20NonStandardInterface(cErc20.underlying()).decimals();
        }

        return RTokenMetadata({
            cToken: address(rToken),
            exchangeRateCurrent: exchangeRateCurrent,
            supplyRatePerBlock: rToken.supplyRatePerBlock(),
            borrowRatePerBlock: rToken.borrowRatePerBlock(),
            reserveFactorMantissa: rToken.reserveFactorMantissa(),
            totalBorrows: rToken.totalBorrows(),
            totalReserves: rToken.totalReserves(),
            totalSupply: rToken.totalSupply(),
            totalCash: rToken.getCash(),
            isListed: isListed,
            collateralFactorMantissa: collateralFactorMantissa,
            underlyingAssetAddress: underlyingAssetAddress,
            cTokenDecimals: rToken.decimals(),
            underlyingDecimals: underlyingDecimals
        });
    }

    function cTokenMetadataAll(RToken[] calldata cTokens) external returns (RTokenMetadata[] memory) {
        uint cTokenCount = cTokens.length;
        RTokenMetadata[] memory res = new RTokenMetadata[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenMetadata(cTokens[i]);
        }
        return res;
    }

    struct RTokenBalances {
        address cToken;
        uint balanceOf;
        uint borrowBalanceCurrent;
        uint balanceOfUnderlying;
        uint tokenBalance;
        uint tokenAllowance;
    }

    function cTokenBalances(RToken cToken, address payable account) public returns (RTokenBalances memory) {
        uint balanceOf = cToken.balanceOf(account);
        uint borrowBalanceCurrent = cToken.borrowBalanceCurrent(account);
        uint balanceOfUnderlying = cToken.balanceOfUnderlying(account);
        uint tokenBalance;
        uint tokenAllowance;

        if (compareStrings(cToken.symbol(), "cETH")) {
            tokenBalance = account.balance;
            tokenAllowance = account.balance;
        } else {
            RErc20 cErc20 = RErc20(address(cToken));
            ERC20NonStandardInterface underlying = ERC20NonStandardInterface(cErc20.underlying());
            tokenBalance = underlying.balanceOf(account);
            tokenAllowance = underlying.allowance(account, address(cToken));
        }

        return RTokenBalances({
            cToken: address(cToken),
            balanceOf: balanceOf,
            borrowBalanceCurrent: borrowBalanceCurrent,
            balanceOfUnderlying: balanceOfUnderlying,
            tokenBalance: tokenBalance,
            tokenAllowance: tokenAllowance
        });
    }

    function cTokenBalancesAll(RToken[] calldata cTokens, address payable account) external returns (RTokenBalances[] memory) {
        uint cTokenCount = cTokens.length;
        RTokenBalances[] memory res = new RTokenBalances[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenBalances(cTokens[i], account);
        }
        return res;
    }

    struct RTokenUnderlyingPrice {
        address cToken;
        uint underlyingPrice;
    }

    function cTokenUnderlyingPrice(RToken cToken) public returns (RTokenUnderlyingPrice memory) {
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(cToken.comptroller()));
        PriceOracle priceOracle = comptroller.oracle();

        return RTokenUnderlyingPrice({
            cToken: address(cToken),
            underlyingPrice: priceOracle.getUnderlyingPrice(cToken)
        });
    }

    function cTokenUnderlyingPriceAll(RToken[] calldata cTokens) external returns (RTokenUnderlyingPrice[] memory) {
        uint cTokenCount = cTokens.length;
        RTokenUnderlyingPrice[] memory res = new RTokenUnderlyingPrice[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenUnderlyingPrice(cTokens[i]);
        }
        return res;
    }

    struct AccountLimits {
        RToken[] markets;
        uint liquidity;
        uint shortfall;
    }

    function getAccountLimits(ComptrollerLensInterface comptroller, address account) public returns (AccountLimits memory) {
        (uint errorCode, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(account);
        require(errorCode == 0);

        return AccountLimits({
            markets: comptroller.getAssetsIn(account),
            liquidity: liquidity,
            shortfall: shortfall
        });
    }

    struct GovReceipt {
        uint proposalId;
        bool hasVoted;
        bool support;
        uint96 votes;
    }

    function getGovReceipts(GovernorAlpha governor, address voter, uint[] memory proposalIds) public view returns (GovReceipt[] memory) {
        uint proposalCount = proposalIds.length;
        GovReceipt[] memory res = new GovReceipt[](proposalCount);
        for (uint i = 0; i < proposalCount; i++) {
            GovernorAlpha.Receipt memory receipt = governor.getReceipt(proposalIds[i], voter);
            res[i] = GovReceipt({
                proposalId: proposalIds[i],
                hasVoted: receipt.hasVoted,
                support: receipt.support,
                votes: receipt.votes
            });
        }
        return res;
    }

    struct GovProposal {
        uint proposalId;
        address proposer;
        uint eta;
        address[] targets;
        uint[] values;
        string[] signatures;
        bytes[] calldatas;
        uint startBlock;
        uint endBlock;
        uint forVotes;
        uint againstVotes;
        bool canceled;
        bool executed;
    }

    function setProposal(GovProposal memory res, GovernorAlpha governor, uint proposalId) internal view {
        (
            ,
            address proposer,
            uint eta,
            uint startBlock,
            uint endBlock,
            uint forVotes,
            uint againstVotes,
            bool canceled,
            bool executed
        ) = governor.proposals(proposalId);
        res.proposalId = proposalId;
        res.proposer = proposer;
        res.eta = eta;
        res.startBlock = startBlock;
        res.endBlock = endBlock;
        res.forVotes = forVotes;
        res.againstVotes = againstVotes;
        res.canceled = canceled;
        res.executed = executed;
    }

    function getGovProposals(GovernorAlpha governor, uint[] calldata proposalIds) external view returns (GovProposal[] memory) {
        GovProposal[] memory res = new GovProposal[](proposalIds.length);
        for (uint i = 0; i < proposalIds.length; i++) {
            (
                address[] memory targets,
                uint[] memory values,
                string[] memory signatures,
                bytes[] memory calldatas
            ) = governor.getActions(proposalIds[i]);
            res[i] = GovProposal({
                proposalId: 0,
                proposer: address(0),
                eta: 0,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                startBlock: 0,
                endBlock: 0,
                forVotes: 0,
                againstVotes: 0,
                canceled: false,
                executed: false
            });
            setProposal(res[i], governor, proposalIds[i]);
        }
        return res;
    }

    struct CompBalanceMetadata {
        uint balance;
        uint votes;
        address delegate;
    }

    struct CompVotes {
        uint blockNumber;
        uint votes;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function add(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;
        return c;
    }
}
