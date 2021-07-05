/**
 *Submitted for verification at BscScan.com on 2021-05-03
*/

pragma solidity 0.6.12;
import "moondoge-swap-lib/contracts/token/BEP20/BEP20.sol";
import "../token/MoonDogeToken.sol";


// MoonBar with Governance.
contract MoonBar is BEP20('SpaceTicket Token', 'STT') {
    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MoonCaption).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function burn(address _from ,uint256 _amount) public onlyOwner {
        _burn(_from, _amount);
    }

    // The MODO TOKEN!
    MoonDoge public modo;


    constructor(
        MoonDoge _modo
    ) public {
        modo = _modo;
    }

    // Safe modo transfer function, just in case if rounding error causes pool to not have enough MODOs.
    function safeModoTransfer(address _to, uint256 _amount) public onlyOwner {
        uint256 modoBal = modo.balanceOf(address(this));
        if (_amount > modoBal) {
            modo.transfer(_to, modoBal);
        } else {
            modo.transfer(_to, _amount);
        }
    }
}