pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "../Tokens/RErc20.sol";
import "../PriceOracle/PriceOracle.sol";
import "../Governance/GovernorAlpha.sol";
import "../Tokens/RToken.sol";
import "../Tokens/ERC20NonStandardInterface.sol";
import "../Tokens/NativeAddress.sol";
import "../ROO/ROO.sol";

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
        address rToken;
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
        uint rTokenDecimals;
        uint underlyingDecimals;
    }

    function rTokenMetadata(RToken rToken) public returns (RTokenMetadata memory) {
        uint exchangeRateCurrent = rToken.exchangeRateCurrent();
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(rToken.comptroller()));
        (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(rToken));
        address underlyingAssetAddress;
        uint underlyingDecimals;
        address underlying = rToken.underlying();

        if (underlying == NativeAddress.nativeAddress()) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            RErc20 cErc20 = RErc20(address(rToken));
            underlyingAssetAddress = cErc20.underlying();
            underlyingDecimals = ERC20NonStandardInterface(cErc20.underlying()).decimals();
        }

        return RTokenMetadata({
            rToken: address(rToken),
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
            rTokenDecimals: rToken.decimals(),
            underlyingDecimals: underlyingDecimals
        });
    }

    function rTokenMetadataAll(RToken[] calldata rTokens) external returns (RTokenMetadata[] memory) {
        uint rTokenCount = rTokens.length;
        RTokenMetadata[] memory res = new RTokenMetadata[](rTokenCount);
        for (uint i = 0; i < rTokenCount; i++) {
            res[i] = rTokenMetadata(rTokens[i]);
        }
        return res;
    }

    struct RTokenBalances {
        address rToken;
        uint balanceOf;
        uint borrowBalanceCurrent;
        uint balanceOfUnderlying;
        uint tokenBalance;
        uint tokenAllowance;
    }

    function rTokenBalances(RToken rToken, address payable account) public returns (RTokenBalances memory) {
        uint balanceOf = rToken.balanceOf(account);
        uint borrowBalanceCurrent = rToken.borrowBalanceCurrent(account);
        uint balanceOfUnderlying = rToken.balanceOfUnderlying(account);
        uint tokenBalance;
        uint tokenAllowance;

        if (compareStrings(rToken.symbol(), "cETH")) {
            tokenBalance = account.balance;
            tokenAllowance = account.balance;
        } else {
            RErc20 cErc20 = RErc20(address(rToken));
            ERC20NonStandardInterface underlying = ERC20NonStandardInterface(cErc20.underlying());
            tokenBalance = underlying.balanceOf(account);
            tokenAllowance = underlying.allowance(account, address(rToken));
        }

        return RTokenBalances({
            rToken: address(rToken),
            balanceOf: balanceOf,
            borrowBalanceCurrent: borrowBalanceCurrent,
            balanceOfUnderlying: balanceOfUnderlying,
            tokenBalance: tokenBalance,
            tokenAllowance: tokenAllowance
        });
    }

    function rTokenBalancesAll(RToken[] calldata rTokens, address payable account) external returns (RTokenBalances[] memory) {
        uint rTokenCount = rTokens.length;
        RTokenBalances[] memory res = new RTokenBalances[](rTokenCount);
        for (uint i = 0; i < rTokenCount; i++) {
            res[i] = rTokenBalances(rTokens[i], account);
        }
        return res;
    }

    struct RTokenUnderlyingPrice {
        address rToken;
        uint underlyingPrice;
    }

    function rTokenUnderlyingPrice(RToken rToken) public returns (RTokenUnderlyingPrice memory) {
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(rToken.comptroller()));
        PriceOracle priceOracle = comptroller.oracle();

        return RTokenUnderlyingPrice({
            rToken: address(rToken),
            underlyingPrice: priceOracle.getUnderlyingPrice(rToken)
        });
    }

    function rTokenUnderlyingPriceAll(RToken[] calldata rTokens) external returns (RTokenUnderlyingPrice[] memory) {
        uint rTokenCount = rTokens.length;
        RTokenUnderlyingPrice[] memory res = new RTokenUnderlyingPrice[](rTokenCount);
        for (uint i = 0; i < rTokenCount; i++) {
            res[i] = rTokenUnderlyingPrice(rTokens[i]);
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
