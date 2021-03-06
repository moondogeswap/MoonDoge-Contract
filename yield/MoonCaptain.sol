/**
 *Submitted for verification at BscScan.com on 2021-05-03
*/

pragma solidity 0.6.12;

import 'moondoge-swap-lib/contracts/math/SafeMath.sol';
import 'moondoge-swap-lib/contracts/token/BEP20/IBEP20.sol';
import 'moondoge-swap-lib/contracts/token/BEP20/SafeBEP20.sol';
import 'moondoge-swap-lib/contracts/access/Ownable.sol';

import "../token/MoonDogeToken.sol";

import "./MoonBar.sol";

// import "@nomiclabs/buidler/console.sol";
interface IMigratorCaptain {
    // Perform LP token migration from legacy MoonDogeSwap to ModoSwap.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to MoonDogeSwap LP tokens.
    // ModoSwap must mint EXACTLY the same amount of ModoSwap LP tokens or
    // else something bad will happen. Traditional MoonDogeSwap does not
    // do that so be careful!
    function migrate(IBEP20 token) external returns (IBEP20);
}

// MoonCaptain is the master of Modo. He can make Modo and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once MODO is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MoonCaptain is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of MODOs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accModoPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accModoPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. MODOs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that MODOs distribution occurs.
        uint256 accModoPerShare; // Accumulated MODOs per share, times 1e12. See below.
    }

    // The MODO TOKEN!
    MoonDoge public modo;
    // The MOONBAR TOKEN!
    MoonBar public moonBar;
    // MODO tokens created per block.
    uint256 public modoPerBlock;
    // Bonus muliplier for early modo makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorCaptain public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Check pool if exist
    mapping (address => bool) public poolExist;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when MODO mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdateMultiplier(uint256 prev, uint256 multiplier);
    event UpdateMigrator(address indexed prev, address indexed migrator);


    constructor(
        MoonDoge _modo,
        MoonBar _moonBar,
        uint256 _modoPerBlock,
        uint256 _startBlock
    ) public {
        modo = _modo;
        moonBar = _moonBar;
        modoPerBlock = _modoPerBlock;
        startBlock = _startBlock;

        // staking pool
        poolInfo.push(PoolInfo({
            lpToken: _modo,
            allocPoint: 1000,
            lastRewardBlock: startBlock,
            accModoPerShare: 0
        }));

        poolExist[address(_modo)] = true;
        totalAllocPoint = 1000;

    }

    modifier validatePoolId(uint256 _pid) {
        require (_pid < poolInfo.length, "pool not exist");
        _;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        uint256 prevMultiplier = BONUS_MULTIPLIER;
        BONUS_MULTIPLIER = multiplierNumber;
        emit UpdateMultiplier(prevMultiplier, BONUS_MULTIPLIER);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        require(!poolExist[address(_lpToken)], "pool: already exist");
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accModoPerShare: 0
        }));
        poolExist[address(_lpToken)] = true;
    }

    // Update the given pool's MODO allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner validatePoolId(_pid) {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorCaptain _migrator) public onlyOwner {
        address prevMigrator = migrator;
        migrator = _migrator;
        emit UpdateMigrator(prevMigrator, migrator);
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public validatePoolId(_pid) {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IBEP20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IBEP20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending MODOs on frontend.
    function pendingModo(uint256 _pid, address _user) external view validatePoolId(_pid) returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accModoPerShare = pool.accModoPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 modoReward = multiplier.mul(modoPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accModoPerShare = accModoPerShare.add(modoReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accModoPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }


    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public validatePoolId(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 modoReward = multiplier.mul(modoPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        modo.mint(address(moonBar), modoReward);
        pool.accModoPerShare = pool.accModoPerShare.add(modoReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MoonCaptain for MODO allocation.
    function deposit(uint256 _pid, uint256 _amount) public validatePoolId(_pid) {

        require (_pid != 0, 'deposit MODO by staking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accModoPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeModoTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accModoPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MoonCaptain.
    function withdraw(uint256 _pid, uint256 _amount) public validatePoolId(_pid) {

        require (_pid != 0, 'withdraw MODO by unstaking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accModoPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeModoTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accModoPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Stake MODO tokens to MoonCaptain
    function enterStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accModoPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeModoTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accModoPerShare).div(1e12);

        moonBar.mint(msg.sender, _amount);
        emit Deposit(msg.sender, 0, _amount);
    }

    // Withdraw MODO tokens from STAKING.
    function leaveStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        uint256 pending = user.amount.mul(pool.accModoPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeModoTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accModoPerShare).div(1e12);

        moonBar.burn(msg.sender, _amount);
        emit Withdraw(msg.sender, 0, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public validatePoolId(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe modo transfer function, just in case if rounding error causes pool to not have enough MODOs.
    function safeModoTransfer(address _to, uint256 _amount) internal {
        moonBar.safeModoTransfer(_to, _amount);
    }

}