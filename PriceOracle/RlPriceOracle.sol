
pragma solidity ^0.5.16;

import "./PriceOracle.sol";
import "../Math/SafeMath.sol";
import "../Tokens/NativeAddress.sol";
import "../Tokens/RErc20.sol";
import "./IDexPair.sol";

contract IPriceCollector {
    function setDirectPrice(address[] memory asset, uint[] memory price) public;
}

contract RlPriceOracle is PriceOracle, IPriceCollector {
    mapping(address => uint) prices;
    address public priceAdmin;

    using SafeMath for uint256;

    uint public constant BASE_DECIMAL = 1e18;
    address public usdt;
    address public native;

    mapping(address => bool) public swapLps;
    mapping(address => address) public underlyingExchange;

    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);
    event PriceAdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    modifier onlyAdmin {
        require(msg.sender == priceAdmin, "Price Admin required.");
        _;
    }

    constructor(address _usdt, address _native) public {
        usdt = _usdt;
        native = _native;
        priceAdmin = msg.sender;
    }

    function getUnderlyingPrice(RToken rToken) public view returns (uint) {
        address _underlying = rToken.underlying();
        if (swapLps[_underlying]) {
            return calLpPrice(_underlying);
        }
        if (_underlying == NativeAddress.nativeAddress()) {
            _underlying = native;
        }
        return prices[_underlying];
    }

    function setUnderlyingPrice(RToken rToken, uint underlyingPriceMantissa) public onlyAdmin {
        address asset = rToken.underlying();
        setDirectPrice(asset, underlyingPriceMantissa);
    }

    function setDirectPrice(address _asset, uint _price) public onlyAdmin {
        prices[_asset] = _price;
        emit PricePosted(_asset, prices[_asset], _price, _price);
    }

    function setDirectPrice(address[] memory _assets, uint[] memory _prices) public onlyAdmin {
        require(_assets.length > 0, "At least one asset price is required");
        require(_assets.length == _prices.length, "Assets and prices are not match");

        for (uint i = 0; i < _assets.length; i++) {
            prices[_assets[i]] = _prices[i];
            emit PricePosted(_assets[i], prices[_assets[i]], _prices[i], _prices[i]);
        }
    }

    function setUnderlyingExchange(address underlying, address exchange) external onlyAdmin {
        underlyingExchange[underlying] = exchange;
    }

    function getPrice(address asset) public view returns (uint) {
        if (asset == usdt) {
            return BASE_DECIMAL;
        }
        return prices[asset];
    }

    function addSwapLp(address _pairaddress) external onlyAdmin{
        require(_pairaddress != address(0));
        swapLps[_pairaddress] = true;
    }

    function calLpPrice(address _pairAddress) public view returns (uint){
        uint256 _token0Price = getPrice(IDexPair(_pairAddress).token0());
        uint256 _token1Price = getPrice(IDexPair(_pairAddress).token1());

        (uint112 reserve0, uint112 reserve1, ) = IDexPair(underlyingExchange[_pairAddress]).getReserves();
        uint256 K = uint256(reserve0).mul(uint256(reserve1));
        uint256 P = _token0Price.mul(BASE_DECIMAL).div(_token1Price);

        uint256 r0 = sqrt(K.mul(BASE_DECIMAL).div(P));
        uint256 r1 = sqrt(K.mul(P).div(BASE_DECIMAL));

        uint _totalSupply = IDexPair(_pairAddress).totalSupply().div(10 ** uint(IDexPair(_pairAddress).decimals()));

        uint256 lpPrice = uint256(2).mul(sqrt(K)).mul(sqrt(_token0Price.mul(_token1Price))).div(_totalSupply);

        return lpPrice;
    }

    function transferPriceAdmin(address newAdmin) public onlyAdmin {
        require(newAdmin != address(0), "Ownable: new price admin is the zero address");
        emit PriceAdminTransferred(priceAdmin, newAdmin);
        priceAdmin = newAdmin;
    }

    function sqrt(uint256 x) public pure returns(uint256) {
        uint256 z = x.add(1).div(2); //(x + 1 ) / 2;
        uint256 y = x;
        while(z < y){
            y = z;
            z = x.div(z).add(z).div(2);//( x / z + z ) / 2;
        }
        return y;
    }
}
