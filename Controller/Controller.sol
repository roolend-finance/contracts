pragma solidity ^0.5.16;

import "./Ownable.sol";

contract Controller is Ownable {
    address private _controller;

    event ControllerChanged(address indexed previousController, address indexed newController);

    constructor() public {
        address msgSender = _msgSender();
        _controller = msgSender;
        emit ControllerChanged(address(0), _controller);
    }

    modifier onlyController() {
        require(isController(msg.sender), "!controller");
        _;
    }

    function controller() public view returns (address){
        return _controller;
    }

    function isController(address account) public view returns (bool) {
        return account == _controller;
    }

    function setController(address c) public onlyOwner {
        require(c != address(0), "controller is empty");
        address oldController = _controller;
        _controller = c;
        emit ControllerChanged(oldController, c);
    }
}