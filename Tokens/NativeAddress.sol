pragma solidity ^0.5.16;

library NativeAddress {

    /**
    * @dev returns the address used within the protocol to identify ETH
    * @return the address assigned to ETH
     */
    function nativeAddress() internal pure returns(address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }
}