/**
 *Submitted for verification at BscScan.com on 2021-07-26
*/
// SPDX-License-Identifier: MIT
// File: contracts/RaffleNFT.sol

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



contract RaffleNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping (uint256 => uint8[4]) public raffleInfo;
    mapping (uint256 => uint256) public raffleAmount;
    mapping (uint256 => uint256) public issueIndex;
    mapping (uint256 => bool) public claimInfo;

    constructor() public ERC721("MoonDoge Raffle Ticket", "MDRT") {}

    function newRaffleItem(address player, uint8[4] memory _raffleNumbers, uint256 _amount, uint256 _issueIndex)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        raffleInfo[newItemId] = _raffleNumbers;
        raffleAmount[newItemId] = _amount;
        issueIndex[newItemId] = _issueIndex;
        return newItemId;
    }

    function getRaffleNumbers(uint256 tokenId) external view returns (uint8[4] memory) {
        return raffleInfo[tokenId];
    }
    function getRaffleAmount(uint256 tokenId) external view returns (uint256) {
        return raffleAmount[tokenId];
    }
    function getRaffleIssueIndex(uint256 tokenId) external view returns (uint256) {
        return issueIndex[tokenId];
    }
    function claimReward(uint256 tokenId) external onlyOwner {
        claimInfo[tokenId] = true;
    }
    function multiClaimReward(uint256[] memory _tokenIds) external onlyOwner {
        for (uint i = 0; i < _tokenIds.length; i++) {
            claimInfo[_tokenIds[i]] = true;
        }
    }
    function burn(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
    }
    function getClaimStatus(uint256 tokenId) external view returns (bool) {
        return claimInfo[tokenId];
    }
}