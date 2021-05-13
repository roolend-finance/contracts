pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "../Math/SafeMath.sol";
import "./PriceOracle.sol";
import "../Tokens/NativeAddress.sol";
import "../Tokens/RErc20.sol";
import "./IDexPair.sol";

contract DexPrice is PriceOracle {
    /**
     * @notice Administrator for this contract
     */
    address payable public admin;

    using SafeMath for uint256;

    uint public constant BASE_DECIMAL = 1e18;
    address public usdt;
    address public native;

    mapping(address => address) public underlyingExchange;

    mapping(address => bool) public swapLps;

    constructor(address _usdt, address _native) public {
        usdt = _usdt;
        native = _native;
        admin = msg.sender;
    }

    function getUnderlyingPrice(RToken cToken) external view returns (uint){
        address _underlying = cToken.underlying();
        if (swapLps[_underlying]) {
            return calLpPrice(_underlying);
        }
        if (_underlying == NativeAddress.nativeAddress()) {
            _underlying = native;
        }
        return getPrice(_underlying);
    }


    function getPrice(address _address) public view returns (uint){
        if (_address == usdt) {
            return BASE_DECIMAL;
        }
        return IDexPair(underlyingExchange[_address]).price(_address, BASE_DECIMAL);
    }

    function getPriceBaseDecimals(address _address) public view returns (uint){
        if (_address == usdt) {
            return BASE_DECIMAL;
        }
        ERC20NonStandardInterface token0 = ERC20NonStandardInterface(_address);
        ERC20NonStandardInterface token1 = ERC20NonStandardInterface(usdt);
        uint decimal = 10 ** uint((BASE_DECIMAL + token0.decimals() - token1.decimals()));
        return IDexPair(underlyingExchange[_address]).price(_address, decimal);
    }

    function setUnderlyingExchange(address underlying, address exchange) external {
        require(msg.sender == admin, "must admin");
        underlyingExchange[underlying] = exchange;
    }

    function addSwapLp(address _pairaddress) external {
        require(msg.sender == admin, "must admin");
        swapLps[_pairaddress] = true;
    }

    function calLpPrice(address _pairAddress) public view returns (uint){

        address token0 = IDexPair(_pairAddress).token0();
        address token1 = IDexPair(_pairAddress).token1();

        uint _totalSupply = IDexPair(_pairAddress).totalSupply().div(10 ** uint(IDexPair(_pairAddress).decimals()));

        uint _totalToken0 = RErc20(token0).balanceOf(_pairAddress);

        uint _totalToken1 = RErc20(token1).balanceOf(_pairAddress);

        uint _token0Decimal = RErc20(token0).decimals();
        uint _token1Decimal = RErc20(token1).decimals();


        uint _token0Price = getPrice(token0);

        uint _lpPerToken0 =
        (_totalToken0.mul(_token0Price)).div(_totalSupply.mul(10 ** _token0Decimal));


        uint _token1Price = getPrice(token1);

        uint _lpPerToken1 = (_totalToken1.mul(_token1Price)).div(_totalSupply.mul(10 ** _token1Decimal));

        return _lpPerToken0.add(_lpPerToken1);

    }
}