pragma solidity >=0.5.0;

interface IMoonDogeFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    event UpdateFeeTo(address indexed from, address indexed to);
    event UpdateFeeToSetter(address indexed from, address indexed to);
    event UpdateFeePct(uint indexed pre, uint indexed pct);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function feePct() external view returns (uint);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
