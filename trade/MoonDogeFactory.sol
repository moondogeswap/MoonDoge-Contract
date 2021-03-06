/**
 *Submitted for verification at BscScan.com on 2021-05-03
*/

pragma solidity =0.5.16;

import './interfaces/IMoonDogeFactory.sol';
import './MoonDogePair.sol';

contract MoonDogeFactory is IMoonDogeFactory {
    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(MoonDogePair).creationCode));

    address public feeTo;
    address public feeToSetter;
    uint public feePct;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    event UpdateFeeTo(address indexed prev, address indexed to);
    event UpdateFeeToSetter(address indexed prev, address indexed to);
    event UpdateFeePct(uint indexed prev, uint indexed pct);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
        feePct = 4;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'MoonDoge: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'MoonDoge: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'MoonDoge: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(MoonDogePair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IMoonDogePair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'MoonDoge: FORBIDDEN');
        address prevFeeTo = feeTo;
        feeTo = _feeTo;
        emit UpdateFeeTo(prevFeeTo, feeTo);
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'MoonDoge: FORBIDDEN');
        address prevFeeToSetter = feeToSetter;
        feeToSetter = _feeToSetter;
        emit UpdateFeeToSetter(prevFeeToSetter, feeToSetter);
    }

    function setFeePct(uint _feePct) external {
        require(feePct == _feePct, 'MoonDoge: FORBIDDEN');
        uint prevFeePct = feePct;
        feePct = _feePct;
        emit UpdateFeePct(prevFeePct, feePct);
    }
}