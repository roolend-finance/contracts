pragma solidity ^0.5.16;

import "../../Controller/Context.sol";
import "./OIP20.sol";

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
contract OIP20Burnable is Context, OIP20 {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) external returns (bool success) {
        return _burn(_msgSender(), amount);
    }

    /**
     * @dev See {ERC20-_burnFrom}.
     */
    function burnFrom(address account, uint256 amount) external returns (bool success) {
        return _burnFrom(account, amount);
    }
}
