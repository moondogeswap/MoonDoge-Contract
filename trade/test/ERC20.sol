pragma solidity =0.5.16;

import '../MoonDogeERC20.sol';

contract ERC20 is MoonDogeERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}
