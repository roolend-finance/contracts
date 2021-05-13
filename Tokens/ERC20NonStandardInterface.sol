pragma solidity ^0.5.16;

interface ERC20NonStandardInterface {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);

    function allowance(address owner, address spender) external view returns (uint256 remaining);

    // 事件，用来通知客户端交易发生 ERC20标准
    event Transfer(address indexed from, address indexed to, uint256 value);


    function transfer(address dst, uint256 amount) external returns (bool success);

    function transferFrom(address src, address dst, uint256 amount) external returns (bool success);

    function approve(address _spender, uint256 _value) external returns (bool success);
}
