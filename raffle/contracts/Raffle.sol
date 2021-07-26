/**
 *Submitted for verification at BscScan.com on 2021-07-26
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./RaffleNFT.sol";
import "./RaffleOwnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";

// import "@nomiclabs/buidler/console.sol";

// 4 numbers
contract Raffle is RaffleOwnable, Initializable {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using SafeERC20 for IERC20;

    uint8 constant keyLengthForEachBuy = 11;
    // Allocation for first/sencond/third reward
    uint8[3] public allocation;
    uint8 constant public totalAlloc = 100;
    // The TOKEN to buy raffle
    IERC20 public modo;
    // The Raffle NFT for tickets
    RaffleNFT public raffleNFT;
    // adminAddress
    address public adminAddress;
    // burnAddress
    address public burnAddress;
    // maxNumber
    uint8 public maxNumber;
    // minPrice, if decimal is not 18, please reset it
    uint256 public minPrice;

    // =================================

    // issueId => winningNumbers[numbers]
    mapping (uint256 => uint8[4]) public historyNumbers;
    // issueId => [tokenId]
    mapping (uint256 => uint256[]) public raffleInfo;
    // issueId => [totalAmount, firstMatchAmount, secondMatchingAmount, thirdMatchingAmount]
    mapping (uint256 => uint256[]) public historyAmount;
    // issueId => trickyNumber => buyAmountSum
    mapping (uint256 => mapping(uint64 => uint256)) public userBuyAmountSum;
    // address => [tokenId]
    mapping (address => uint256[]) public userInfo;

    uint256 public issueIndex = 0;
    uint256 public totalAddresses = 0;
    uint256 public totalAmount = 0;
    uint256 public lastTimestamp;

    uint8[4] public winningNumbers;

    // default false
    bool public drawingPhase;

    // =================================

    event Buy(address indexed user, uint256 tokenId);
    event Drawing(uint256 indexed issueIndex, uint8[4] winningNumbers);
    event Claim(address indexed user, uint256 tokenid, uint256 amount);
    event DevWithdraw(address indexed user, uint256 amount);
    event Reset(uint256 indexed issueIndex);
    event MultiClaim(address indexed user, uint256[] tickets, uint256 amount);
    event MultiBuy(address indexed user, uint256[] tickets, uint256 amount);
    event UpdateMaxNumber(uint8 indexed prev, uint8 indexed number);
    event UpdateAllocation(uint8[3] indexed prev, uint8[3] indexed alloc);

    constructor() public {
    }

    function initialize(
        IERC20 _modo,
        RaffleNFT _raffle,
        uint256 _minPrice,
        uint8 _maxNumber,
        address _owner,
        address _adminAddress,
        address _burnAddress
    ) public initializer {
        modo = _modo;
        raffleNFT = _raffle;
        minPrice = _minPrice;
        maxNumber = _maxNumber;
        adminAddress = _adminAddress;
        burnAddress = _burnAddress;
        lastTimestamp = block.timestamp;
        allocation = [50, 30, 15];
        initOwner(_owner);
    }

    uint8[4] private nullTicket = [0,0,0,0];

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "admin: wut?");
        _;
    }

    function drawed() public view returns(bool) {
        return winningNumbers[0] != 0;
    }

    function reset() external onlyAdmin {
        require(drawed(), "drawed?");
        lastTimestamp = block.timestamp;
        totalAmount = 0;
        winningNumbers[0] = 0;
        winningNumbers[1] = 0;
        winningNumbers[2] = 0;
        winningNumbers[3] = 0;
        drawingPhase = false;
        issueIndex = issueIndex + 1;
        uint256 interBuyAmount = 0;
        if(getMatchingRewardAmount(issueIndex-1, 4) == 0) {
            // uint256 amount = getTotalRewards(issueIndex-1).mul(allocation[0]).div(100);
            // interBuyAmount += amount;
            interBuyAmount = interBuyAmount.add(getTotalRewards(issueIndex-1).mul(allocation[0]).div(100));
        }
        if(getMatchingRewardAmount(issueIndex-1, 3) == 0) {
            interBuyAmount = interBuyAmount.add(getTotalRewards(issueIndex-1).mul(allocation[1]).div(100));
        }
        if(getMatchingRewardAmount(issueIndex-1, 2) == 0) {
            interBuyAmount = interBuyAmount.add(getTotalRewards(issueIndex-1).mul(allocation[2]).div(100));
        }
        if(interBuyAmount > 0) {
            internalBuy(interBuyAmount, nullTicket);
        }

        // match only one should be transferto burn
        uint256 burnAmount = getTotalRewards(issueIndex-1).mul(totalAlloc.sub(allocation[0]).sub(allocation[1]).sub(allocation[2])).div(100);
        if(burnAmount > 0) {
            modo.safeTransfer(burnAddress, burnAmount);
        }
        emit Reset(issueIndex);
    }

    function enterDrawingPhase() external onlyAdmin {
        require(!drawed(), 'drawed');
        drawingPhase = true;
    }

    // add externalRandomNumber to prevent node validators exploiting
    function drawing(uint256 _externalRandomNumber) external onlyAdmin {
        require(!drawed(), "reset?");
        require(drawingPhase, "enter drawing phase first");
        bytes32 _structHash;
        uint256 _randomNumber;
        uint8 _maxNumber = maxNumber;
        bytes32 _blockhash = blockhash(block.number-1);

        // waste some gas fee here
        for (uint i = 0; i < 10; i++) {
            getTotalRewards(issueIndex);
        }
        uint256 gasleft = gasleft();

        // 1
        _structHash = keccak256(
            abi.encode(
                _blockhash,
                totalAddresses,
                gasleft,
                _externalRandomNumber
            )
        );
        _randomNumber = uint256(_structHash);
        assembly {_randomNumber := add(mod(_randomNumber, _maxNumber),1)}
        winningNumbers[0]=uint8(_randomNumber);

        // 2
        _structHash = keccak256(
            abi.encode(
                _blockhash,
                totalAmount,
                gasleft,
                _externalRandomNumber
            )
        );
        _randomNumber = uint256(_structHash);
        assembly {_randomNumber := add(mod(_randomNumber, _maxNumber),1)}
        winningNumbers[1] = uint8(_randomNumber);

        // 3
        _structHash = keccak256(
            abi.encode(
                _blockhash,
                lastTimestamp,
                gasleft,
                _externalRandomNumber
            )
        );
        _randomNumber = uint256(_structHash);
        assembly {_randomNumber := add(mod(_randomNumber, _maxNumber),1)}
        winningNumbers[2] = uint8(_randomNumber);

        // 4
        _structHash = keccak256(
            abi.encode(
                _blockhash,
                gasleft,
                _externalRandomNumber
            )
        );
        _randomNumber = uint256(_structHash);
        assembly {_randomNumber := add(mod(_randomNumber, _maxNumber),1)}
        winningNumbers[3] = uint8(_randomNumber);
        historyNumbers[issueIndex] = winningNumbers;
        historyAmount[issueIndex] = calculateMatchingRewardAmount();
        drawingPhase = false;
        emit Drawing(issueIndex, winningNumbers);
    }

    // only use for adding rewards
    function internalBuy(uint256 _price, uint8[4] memory _numbers) public {
        require (!drawed(), 'drawed, can not buy now');
        for (uint i = 0; i < 4; i++) {
            require (_numbers[i] <= maxNumber, 'exceed the maximum');
        }
        // buy empty number and burn tokenId
        uint256 tokenId = raffleNFT.newRaffleItem(address(this), _numbers, _price, issueIndex);
        raffleNFT.burn(tokenId);

        totalAmount = totalAmount.add(_price);
        lastTimestamp = block.timestamp;
        emit Buy(address(this), tokenId);

    }

    function buy(uint256 _price, uint8[4] memory _numbers) external {
        require(!drawed(), 'drawed, can not buy now');
        require(!drawingPhase, 'drawing, can not buy now');
        require(_price >= minPrice, 'price must above minPrice');
        for (uint i = 0; i < 4; i++) {
            require (_numbers[i] <= maxNumber && _numbers[i] > 0, 'exceed number scope');
        }
        uint256 tokenId = raffleNFT.newRaffleItem(msg.sender, _numbers, _price, issueIndex);
        raffleInfo[issueIndex].push(tokenId);
        if (userInfo[msg.sender].length == 0) {
            totalAddresses = totalAddresses + 1;
        }
        userInfo[msg.sender].push(tokenId);
        totalAmount = totalAmount.add(_price);
        lastTimestamp = block.timestamp;
        uint64[keyLengthForEachBuy] memory userNumberIndex = generateNumberIndexKey(_numbers);
        for (uint i = 0; i < keyLengthForEachBuy; i++) {
            userBuyAmountSum[issueIndex][userNumberIndex[i]] = userBuyAmountSum[issueIndex][userNumberIndex[i]].add(_price);
        }
        modo.safeTransferFrom(address(msg.sender), address(this), _price);
        emit Buy(msg.sender, tokenId);
    }

    function  multiBuy(uint256 _price, uint8[4][] memory _numbers) external {
        require (!drawed(), 'drawed, can not buy now');
        require (!drawingPhase, "enter drawing phase first");
        require (_price >= minPrice, 'price must above minPrice');
        uint256[] memory tickets = new uint256[](_numbers.length);
        uint256 totalPrice = 0;
        for (uint i = 0; i < _numbers.length; i++) {
            for (uint j = 0; j < 4; j++) {
                require (_numbers[i][j] <= maxNumber && _numbers[i][j] > 0, 'exceed number scope');
            }
            uint256 tokenId = raffleNFT.newRaffleItem(msg.sender, _numbers[i], _price, issueIndex);
            tickets[i] = tokenId;
            raffleInfo[issueIndex].push(tokenId);
            if (userInfo[msg.sender].length == 0) {
                totalAddresses = totalAddresses + 1;
            }
            userInfo[msg.sender].push(tokenId);
            lastTimestamp = block.timestamp;

            uint64[keyLengthForEachBuy] memory numberIndexKey = generateNumberIndexKey(_numbers[i]);
            for (uint k = 0; k < keyLengthForEachBuy; k++) {
                userBuyAmountSum[issueIndex][numberIndexKey[k]] = userBuyAmountSum[issueIndex][numberIndexKey[k]].add(_price);
            }
        }
        totalPrice = _numbers.length.mul(_price);
        modo.safeTransferFrom(address(msg.sender), address(this), totalPrice);
        totalAmount = totalAmount.add(totalPrice);
        emit MultiBuy(msg.sender, tickets, totalPrice);
    }

    function claimReward(uint256 _tokenId) external {
        require(msg.sender == raffleNFT.ownerOf(_tokenId), "not from owner");
        require (!raffleNFT.getClaimStatus(_tokenId), "claimed");
        uint256 reward = getRewardView(_tokenId);
        raffleNFT.claimReward(_tokenId);
        if(reward>0) {
            modo.safeTransfer(address(msg.sender), reward);
        }
        emit Claim(msg.sender, _tokenId, reward);
    }

    function  multiClaim(uint256[] memory _tickets) external {
        uint256 totalReward = 0;
        for (uint i = 0; i < _tickets.length; i++) {
            require (msg.sender == raffleNFT.ownerOf(_tickets[i]), "not from owner");
            require (!raffleNFT.getClaimStatus(_tickets[i]), "claimed");
            uint256 reward = getRewardView(_tickets[i]);
            if(reward>0) {
                totalReward = reward.add(totalReward);
            }
        }
        raffleNFT.multiClaimReward(_tickets);
        if(totalReward>0) {
            modo.safeTransfer(address(msg.sender), totalReward);
        }
        emit MultiClaim(msg.sender, _tickets, totalReward);
    }

    function generateNumberIndexKey(uint8[4] memory number) public pure returns (uint64[keyLengthForEachBuy] memory) {
        uint64[4] memory tempNumber;
        tempNumber[0] = uint64(number[0]);
        tempNumber[1] = uint64(number[1]);
        tempNumber[2] = uint64(number[2]);
        tempNumber[3] = uint64(number[3]);

        uint64[keyLengthForEachBuy] memory result;
        // match all
        result[0] = bitwiseLeft(tempNumber[0], 48) + bitwiseLeft(1, 40) + bitwiseLeft(tempNumber[1], 32) + bitwiseLeft(2, 24) + bitwiseLeft(tempNumber[2] ,16) + bitwiseLeft(3, 8) + tempNumber[3];
        // match 3
        result[1] = bitwiseLeft(tempNumber[0], 32) + bitwiseLeft(1, 24) + bitwiseLeft(tempNumber[1], 16) + bitwiseLeft(2, 8) + tempNumber[2];
        result[2] = bitwiseLeft(tempNumber[0], 32) + bitwiseLeft(1, 24) + bitwiseLeft(tempNumber[1], 16) + bitwiseLeft(3, 8) + tempNumber[3];
        result[3] = bitwiseLeft(tempNumber[0], 32) + bitwiseLeft(2, 24) + bitwiseLeft(tempNumber[2], 16) + bitwiseLeft(3, 8) + tempNumber[3];
        result[4] = bitwiseLeft(1, 40) + bitwiseLeft(tempNumber[1], 32) + bitwiseLeft(2, 24) + bitwiseLeft(tempNumber[2], 16) + bitwiseLeft(3, 8) + tempNumber[3];
        // match 2
        result[5] = bitwiseLeft(tempNumber[0], 16) + bitwiseLeft(1, 8) + tempNumber[1];
        result[6] = bitwiseLeft(tempNumber[0], 16) + bitwiseLeft(2, 8) + tempNumber[2];
        result[7] = bitwiseLeft(tempNumber[0], 16) + bitwiseLeft(3, 8) + tempNumber[3];
        // match 1
        result[8] = bitwiseLeft(1, 24) + bitwiseLeft(tempNumber[1], 16) + bitwiseLeft(2, 8) + tempNumber[2];
        result[9] = bitwiseLeft(1, 24) + bitwiseLeft(tempNumber[1], 16) + bitwiseLeft(3, 8) + tempNumber[3];
        result[10] = bitwiseLeft(2, 24) + bitwiseLeft(tempNumber[2], 16) + bitwiseLeft(3, 8) + tempNumber[3];

        return result;
    }

    function calculateMatchingRewardAmount() internal view returns (uint256[4] memory) {
        uint64[keyLengthForEachBuy] memory numberIndexKey = generateNumberIndexKey(winningNumbers);

        uint256 totalAmout1 = userBuyAmountSum[issueIndex][numberIndexKey[0]];

        uint256 sumForTotalAmout2 = userBuyAmountSum[issueIndex][numberIndexKey[1]];
        sumForTotalAmout2 = sumForTotalAmout2.add(userBuyAmountSum[issueIndex][numberIndexKey[2]]);
        sumForTotalAmout2 = sumForTotalAmout2.add(userBuyAmountSum[issueIndex][numberIndexKey[3]]);
        sumForTotalAmout2 = sumForTotalAmout2.add(userBuyAmountSum[issueIndex][numberIndexKey[4]]);

        uint256 totalAmout2 = sumForTotalAmout2.sub(totalAmout1.mul(4));

        uint256 sumForTotalAmout3 = userBuyAmountSum[issueIndex][numberIndexKey[5]];
        sumForTotalAmout3 = sumForTotalAmout3.add(userBuyAmountSum[issueIndex][numberIndexKey[6]]);
        sumForTotalAmout3 = sumForTotalAmout3.add(userBuyAmountSum[issueIndex][numberIndexKey[7]]);
        sumForTotalAmout3 = sumForTotalAmout3.add(userBuyAmountSum[issueIndex][numberIndexKey[8]]);
        sumForTotalAmout3 = sumForTotalAmout3.add(userBuyAmountSum[issueIndex][numberIndexKey[9]]);
        sumForTotalAmout3 = sumForTotalAmout3.add(userBuyAmountSum[issueIndex][numberIndexKey[10]]);

        uint256 totalAmout3 = sumForTotalAmout3.add(totalAmout1.mul(6)).sub(sumForTotalAmout2.mul(3));

        return [totalAmount, totalAmout1, totalAmout2, totalAmout3];
    }

    function getMatchingRewardAmount(uint256 _issueIndex, uint256 _matchingNumber) public view returns (uint256) {
        return historyAmount[_issueIndex][5 - _matchingNumber];
    }

    function getTotalRewards(uint256 _issueIndex) public view returns(uint256) {
        require (_issueIndex <= issueIndex, '_issueIndex <= issueIndex');

        if(!drawed() && _issueIndex == issueIndex) {
            return totalAmount;
        }
        return historyAmount[_issueIndex][0];
    }

    function getRewardView(uint256 _tokenId) public view returns(uint256) {
        uint256 _issueIndex = raffleNFT.getRaffleIssueIndex(_tokenId);
        uint8[4] memory raffleNumbers = raffleNFT.getRaffleNumbers(_tokenId);
        uint8[4] memory _winningNumbers = historyNumbers[_issueIndex];
        require(_winningNumbers[0] != 0, "not drawed");

        uint256 matchingNumber = 0;
        for (uint i = 0; i < raffleNumbers.length; i++) {
            if (_winningNumbers[i] == raffleNumbers[i]) {
                matchingNumber = matchingNumber + 1;
            }
        }
        uint256 reward = 0;
        if (matchingNumber > 1) {
            uint256 amount = raffleNFT.getRaffleAmount(_tokenId);
            uint256 poolAmount = getTotalRewards(_issueIndex).mul(allocation[4-matchingNumber]).div(100);
            reward = amount.mul(1e12).div(getMatchingRewardAmount(_issueIndex, matchingNumber)).mul(poolAmount);
        }
        return reward.div(1e12);
    }


    // Update admin address by the previous dev.
    function setAdmin(address _adminAddress) public onlyOwner {
        adminAddress = _adminAddress;
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function adminWithdraw(uint256 _amount) public onlyAdmin {
        modo.safeTransfer(address(msg.sender), _amount);
        emit DevWithdraw(msg.sender, _amount);
    }

    // Set the minimum price for one ticket
    function setMinPrice(uint256 _price) external onlyAdmin {
        minPrice = _price;
    }

        // Update burn address by the previous dev.
    function setBurnAddress(address _burnAddress) public onlyOwner {
        burnAddress = _burnAddress;
    }

    // Set the maxNumber price for raffle
    function setMaxNumber(uint8 _maxNumber) external onlyAdmin {
        uint8 prevMaxNumber = maxNumber;
        maxNumber = _maxNumber;
        emit UpdateMaxNumber(prevMaxNumber, maxNumber);
    }

    // Set the allocation for one reward
    function setAllocation(uint8 _allocation1, uint8 _allocation2, uint8 _allocation3) external onlyAdmin {
        uint256 _totalAlloc = _allocation1.add(_allocation2).add(_allocation3);
        require(totalAlloc > _totalAlloc && _totalAlloc > 0, "invalid alloc");
        uint8[3] memory prevAllocation = [allocation[0], allocation[1], allocation[2]];
        allocation = [_allocation1, _allocation2, _allocation3];
        emit UpdateAllocation(prevAllocation, allocation);
    }

    function bitwiseLeft(uint64 number, uint64 bitwise) internal pure returns(uint64) {
        return number << bitwise;
    }
}