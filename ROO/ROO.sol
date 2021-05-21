pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./OIP20/OIP20Detailed.sol";
import "./OIP20/OIP20Burnable.sol";
import "../Tokens/Reservoir.sol";
import "../Controller/Ownable.sol";

contract ROO is OIP20Detailed, OIP20Burnable, Ownable {

    // 共发行2100万枚
    uint public constant _totalSupply = 21000000e18;
    Reservoir public reservoir_;

    // notify the reservoir has changed by this event
    event ReservoirChanged(address indexed oldOne, address indexed newOne);

    constructor () public OIP20Detailed("Roolend", "ROO", 18) {
    }

    function _setReservoir(Reservoir reservoir) public {
        if (address(reservoir_) != address(reservoir)) {
            Reservoir oldOne = reservoir_;
            reservoir_ = reservoir;
            emit ReservoirChanged(address(oldOne), address(reservoir_));
        }
    }

    // 调用时传入Reservoir的地址，代币由Reservoir负责分发
    function mint(address _to) public {
        // required reservoir
        require(address(reservoir_) != address(0), "please set reservoir at first");
        // required reservoir call
        require(msg.sender == address(reservoir_), "only reservoir can call this");
        // required call this once
        require(totalSupply() == 0, "you can only mint once");
        _mint(_to, _totalSupply);
    }
}

