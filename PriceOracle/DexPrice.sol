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

    function getUnderlyingPrice(RToken rToken) external view returns (uint){
        address _underlying = rToken.underlying();
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
        return price(_address, BASE_DECIMAL);
    }

    function getPriceBaseDecimals(address _address) public view returns (uint){
        if (_address == usdt) {
            return BASE_DECIMAL;
        }
        ERC20NonStandardInterface token0 = ERC20NonStandardInterface(_address);
        ERC20NonStandardInterface token1 = ERC20NonStandardInterface(usdt);
        uint decimal = 10 ** uint((BASE_DECIMAL + token0.decimals() - token1.decimals()));
        return price(_address, decimal);
    }

    function setUnderlyingExchange(address underlying, address exchange) external {
        require(msg.sender == admin, "must admin");
        underlyingExchange[underlying] = exchange;
    }

    function addSwapLp(address _pairaddress) external {
        require(msg.sender == admin, "must admin");
        require(_pairaddress != address(0));
        swapLps[_pairaddress] = true;
    }

    function price(address _address, uint256 baseDecimal) public view returns (uint256) {
        address token0 = IDexPair(underlyingExchange[_address]).token0();
        address token1 = IDexPair(underlyingExchange[_address]).token1();
        (uint112 reserve0, uint112 reserve1, ) = IDexPair(underlyingExchange[_address]).getReserves();


        if ((token0 != _address && token1 != _address) || 0 == reserve0 || 0 == reserve1) {
            return 0;
        }
        if (token0 == _address) {
            return uint256(reserve1).mul(baseDecimal).div(uint256(reserve0));
        } else {
            return uint256(reserve0).mul(baseDecimal).div(uint256(reserve1));
        }
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