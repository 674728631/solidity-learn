// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "hardhat/console.sol";

contract MetaNodeStake is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    // ************************************** 不变量 **************************************

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");       // 管理员角色
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");   // 升级角色

    uint256 public constant ETH_PID = 0;    // ETH 池的 ID
    
    // ************************************** 数据结构 **************************************
    /*
    基本逻辑：在任何时间点，用户有权获得但尚未分配的 MetaNode 数量为：
    pending MetaNode = (user.stAmount * pool.accMetaNodePerST) - user.finishedMetaNode

    当用户向池中存入或提取质押代币时，会发生以下操作：
    1. 池的 `accMetaNodePerST` 和 `lastRewardBlock` 会被更新。
    2. 用户会收到待分配的 MetaNode，发送到其地址。
    3. 用户的 `stAmount` 会被更新。
    4. 用户的 `finishedMetaNode` 会被更新。
    */
    struct Pool {
        // 质押代币的地址
        address stTokenAddress;
        // 池的权重
        uint256 poolWeight;
        // 最后一次分配 MetaNode 的区块号
        uint256 lastRewardBlock;
        // 池中质押代币的单位奖励
        uint256 accMetaNodePerST;
        // 质押代币的总量
        uint256 stTokenAmount;
        // 最小质押数量
        uint256 minDepositAmount;
        // 提取锁定的区块数
        uint256 unstakeLockedBlocks;
    }

    struct UnstakeRequest {
        // 请求提取的数量
        uint256 amount;
        // 请求提取数量可释放的区块数
        uint256 unlockBlocks;
    }

    struct User {
        // 用户提供的质押代币数量
        uint256 stAmount;
        // 已分配给用户的 MetaNode 数量
        uint256 finishedMetaNode;
        // 待领取的 MetaNode 数量
        uint256 pendingMetaNode;
        // 提取请求列表
        UnstakeRequest[] requests;
    }

    // **************************************  状态变量 **************************************
    // MetaNodeStake 开始的第一个区块
    uint256 public startBlock;
    // MetaNodeStake 结束的第一个区块
    uint256 public endBlock;
    // 每个区块的 MetaNode 奖励数量
    uint256 public MetaNodePerBlock;

    // 暂停提取功能
    bool public withdrawPaused;
    // 暂停领取功能
    bool public claimPaused;

    // MetaNode 代币
    IERC20 public MetaNode;

    // 总池权重 / 所有池权重的总和
    uint256 public totalPoolWeight;
    Pool[] public pool;

    // 池 ID => 用户地址 => 用户信息
    mapping (uint256 => mapping (address => User)) public user;

    // ************************************** 事件 **************************************


    event SetMetaNode(IERC20 indexed MetaNode);

    event PauseWithdraw();

    event UnpauseWithdraw();

    event PauseClaim();

    event UnpauseClaim();

    event SetStartBlock(uint256 indexed startBlock);

    event SetEndBlock(uint256 indexed endBlock);

    event SetMetaNodePerBlock(uint256 indexed MetaNodePerBlock);

    event AddPool(address indexed stTokenAddress, uint256 indexed poolWeight, uint256 indexed lastRewardBlock, uint256 minDepositAmount, uint256 unstakeLockedBlocks);

    event UpdatePoolInfo(uint256 indexed poolId, uint256 indexed minDepositAmount, uint256 indexed unstakeLockedBlocks);

    event SetPoolWeight(uint256 indexed poolId, uint256 indexed poolWeight, uint256 totalPoolWeight);

    event UpdatePool(uint256 indexed poolId, uint256 indexed lastRewardBlock, uint256 totalMetaNode);

    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);

    event RequestUnstake(address indexed user, uint256 indexed poolId, uint256 amount);

    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount, uint256 indexed blockNumber);

    event Claim(address indexed user, uint256 indexed poolId, uint256 MetaNodeReward);

    // ************************************** 修饰器 **************************************

    modifier checkPid(uint256 _pid) {
        require(_pid < pool.length, "invalid pid");
        _;
    }

    modifier whenNotClaimPaused() {
        require(!claimPaused, "claim is paused");
        _;
    }

    modifier whenNotWithdrawPaused() {
        require(!withdrawPaused, "withdraw is paused");
        _;
    }

    /**
     * @notice 设置 MetaNode 代币地址。部署时设置基本信息。
     */
    function initialize(
        IERC20 _MetaNode,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _MetaNodePerBlock
    ) public initializer {
        require(_startBlock <= _endBlock && _MetaNodePerBlock > 0, "invalid parameters");

        __AccessControl_init();     // 初始化访问控制
        __UUPSUpgradeable_init();   // 初始化 UUPS 可升级
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); // 授予默认管理员角色
        _grantRole(UPGRADE_ROLE, msg.sender);       // 授予升级角色
        _grantRole(ADMIN_ROLE, msg.sender);         // 授予管理员角色

        setMetaNode(_MetaNode);     // 设置 MetaNode 代币

        startBlock = _startBlock;   // 设置开始区块
        endBlock = _endBlock;       // 设置结束区块
        MetaNodePerBlock = _MetaNodePerBlock;   // 设置每个区块的 MetaNode 奖励

    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADE_ROLE)
        override
    {

    }

    // ************************************** 管理员函数 **************************************

    /**
     * @notice 设置 MetaNode 代币地址。仅管理员可调用。
     */
    function setMetaNode(IERC20 _MetaNode) public onlyRole(ADMIN_ROLE) {
        MetaNode = _MetaNode;

        emit SetMetaNode(MetaNode);
    }

    /**
     * @notice 暂停提取功能。仅管理员可调用。
     */
    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "withdraw has been already paused");

        withdrawPaused = true;

        emit PauseWithdraw();
    }

    /**
     * @notice 恢复提取功能。仅管理员可调用。
     */
    function unpauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "withdraw has been already unpaused");

        withdrawPaused = false;

        emit UnpauseWithdraw();
    }

    /**
     * @notice 暂停领取功能。仅管理员可调用。
     */
    function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "claim has been already paused");

        claimPaused = true;

        emit PauseClaim();
    }

    /**
     * @notice 恢复领取功能。仅管理员可调用。
     */
    function unpauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "claim has been already unpaused");

        claimPaused = false;

        emit UnpauseClaim();
    }

    /**
     * @notice 设置开始区块。仅管理员可调用。
     */
    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE) {
        require(_startBlock <= endBlock, "start block must be smaller than end block");

        startBlock = _startBlock;

        emit SetStartBlock(_startBlock);
    }

    /**
     * @notice 设置结束区块。仅管理员可调用。
     */
    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(startBlock <= _endBlock, "start block must be smaller than end block");

        endBlock = _endBlock;

        emit SetEndBlock(_endBlock);
    }

    /**
     * @notice 设置每个区块的 MetaNode 奖励数量。仅管理员可调用。
     */
    function setMetaNodePerBlock(uint256 _MetaNodePerBlock) public onlyRole(ADMIN_ROLE) {
        require(_MetaNodePerBlock > 0, "invalid parameter");

        MetaNodePerBlock = _MetaNodePerBlock;

        emit SetMetaNodePerBlock(_MetaNodePerBlock);
    }

    /**
     * @notice 添加一个新的质押池。仅管理员可调用。
     * @param _stTokenAddress 质押代币地址
     * @param _poolWeight 池的权重
     * @param _minDepositAmount 最小质押数量
     * @param _unstakeLockedBlocks 提取锁定的区块数
     */
    function addPool(address _stTokenAddress, uint256 _poolWeight, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks,  bool _withUpdate) public onlyRole(ADMIN_ROLE) {
        // 默认第一个池为ETH池，因此第一个池必须添加stTokenAddress=address（0x0）
        if (pool.length > 0) {
            require(_stTokenAddress != address(0x0), "invalid staking token address");
        } else {
            require(_stTokenAddress == address(0x0), "invalid staking token address");
        }
        // allow the min deposit amount equal to 0
        //require(_minDepositAmount > 0, "invalid min deposit amount");
        require(_unstakeLockedBlocks > 0, "invalid withdraw locked blocks");
        require(block.number < endBlock, "Already ended");

        if (_withUpdate) {
            massUpdatePools();
        }

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalPoolWeight = totalPoolWeight + _poolWeight;

        pool.push(Pool({
            stTokenAddress: _stTokenAddress,
            poolWeight: _poolWeight,
            lastRewardBlock: lastRewardBlock,
            accMetaNodePerST: 0,
            stTokenAmount: 0,
            minDepositAmount: _minDepositAmount,
            unstakeLockedBlocks: _unstakeLockedBlocks
        }));

        emit AddPool(_stTokenAddress, _poolWeight, lastRewardBlock, _minDepositAmount, _unstakeLockedBlocks);
    }

     /**
     * @notice 更新池信息。仅管理员可调用。
     * @param _pid 池 ID
     * @param _minDepositAmount 新的最小质押数量
     * @param _unstakeLockedBlocks 新的提取锁定区块数
     */
    function updatePool(uint256 _pid, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        pool[_pid].minDepositAmount = _minDepositAmount;
        pool[_pid].unstakeLockedBlocks = _unstakeLockedBlocks;

        emit UpdatePoolInfo(_pid, _minDepositAmount, _unstakeLockedBlocks);
    }

    /**
     * @notice 设置池权重。仅管理员可调用。
     * @param _pid 池 ID
     * @param _poolWeight 新的池权重
     * @param _withUpdate 是否在设置权重前更新所有池的奖励（ massUpdatePools ）。
     */
    function setPoolWeight(uint256 _pid, uint256 _poolWeight, bool _withUpdate) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        require(_poolWeight > 0, "invalid pool weight");
        
        if (_withUpdate) {
            massUpdatePools();
        }

        totalPoolWeight = totalPoolWeight - pool[_pid].poolWeight + _poolWeight;
        pool[_pid].poolWeight = _poolWeight;

        emit SetPoolWeight(_pid, _poolWeight, totalPoolWeight);
    }

    // ************************************** QUERY FUNCTION **************************************

    /**
     * @notice Get the length/amount of pool
     */
    function poolLength() external view returns(uint256) {
        return pool.length;
    }

    /**
     * @notice 返回给定_from到_to块的奖励倍数。[_from，_to）
     *
     * @param _from    From block number (included)
     * @param _to      To block number (exluded)
     */
    function getMultiplier(uint256 _from, uint256 _to) public view returns(uint256 multiplier) {
        require(_from <= _to, "invalid block");
        if (_from < startBlock) {_from = startBlock;}
        if (_to > endBlock) {_to = endBlock;}
        require(_from <= _to, "end block must be greater than start block");
        bool success;
        (success, multiplier) = (_to - _from).tryMul(MetaNodePerBlock);
        require(success, "multiplier overflow");
    }

    /**
     * @notice 获取池中待处理的 MetaNode 用户数量
     */
    function pendingMetaNode(uint256 _pid, address _user) external checkPid(_pid) view returns(uint256) {
        return pendingMetaNodeByBlockNumber(_pid, _user, block.number);
    }

    /**
     * @notice 通过池中的块号获取待处理的 MetaNode 用户数量
     */
    function pendingMetaNodeByBlockNumber(uint256 _pid, address _user, uint256 _blockNumber) public checkPid(_pid) view returns(uint256) {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][_user];
        uint256 accMetaNodePerST = pool_.accMetaNodePerST;
        uint256 stSupply = pool_.stTokenAmount;

        if (_blockNumber > pool_.lastRewardBlock && stSupply != 0) {
            uint256 multiplier = getMultiplier(pool_.lastRewardBlock, _blockNumber);
            uint256 MetaNodeForPool = multiplier * pool_.poolWeight / totalPoolWeight;
            accMetaNodePerST = accMetaNodePerST + MetaNodeForPool * (1 ether) / stSupply;
        }

        return user_.stAmount * accMetaNodePerST / (1 ether) - user_.finishedMetaNode + user_.pendingMetaNode;
    }

    /**
     * @notice 获取用户质押数量
     */
    function stakingBalance(uint256 _pid, address _user) external checkPid(_pid) view returns(uint256) {
        return user[_pid][_user].stAmount;
    }

    /**
     * @notice 获取用户提取请求数量
     */
    function withdrawRequests(uint256 _pid, address _user) external checkPid(_pid) view returns(uint256) {
        return user[_pid][_user].requests.length;
    }

    /**
     * @notice 获取提币金额信息，包括锁定解押金额和解锁解押金额
     */
    function withdrawAmount(uint256 _pid, address _user) public checkPid(_pid) view returns(uint256 requestAmount, uint256 pendingWithdrawAmount) {
        User storage user_ = user[_pid][_user];

        for (uint256 i = 0; i < user_.requests.length; i++) {
            if (user_.requests[i].unlockBlocks <= block.number) {
                pendingWithdrawAmount = pendingWithdrawAmount + user_.requests[i].amount;
            }
            requestAmount = requestAmount + user_.requests[i].amount;
        }
    }

    // ************************************** PUBLIC FUNCTION **************************************

    /**
     * @notice 更新池的奖励信息。内部调用。
     * @param _pid 池 ID
     */
    function updatePool(uint256 _pid) public checkPid(_pid) {
        Pool storage pool_ = pool[_pid];
        // 如果当前区块高度 block.number 小于或等于池的最后一次奖励区块 pool_.lastRewardBlock ，说明无需更新，直接返回。
        if (block.number <= pool_.lastRewardBlock) {
            return;
        }
        // 计算从 pool_.lastRewardBlock 到 block.number 之间的区块奖励倍数。
        // 将奖励倍数乘以池的权重 pool_.poolWeight ，得到该池应分配的总奖励 totalMetaNode 。
        (bool success1, uint256 totalMetaNode) = getMultiplier(pool_.lastRewardBlock, block.number).tryMul(pool_.poolWeight);
        require(success1, "overflow");
        // 将总奖励除以所有池的总权重 totalPoolWeight ，得到该池的实际奖励份额。
        (success1, totalMetaNode) = totalMetaNode.tryDiv(totalPoolWeight);
        require(success1, "overflow");

        uint256 stSupply = pool_.stTokenAmount;
        // 如果池中有质押代币（ stSupply > 0 ），则将奖励分配到每单位质押代币的累积奖励 accMetaNodePerST 中：
        if (stSupply > 0) {
            // 将总奖励 totalMetaNode 乘以 1 ether （避免浮点数问题），
            (bool success2, uint256 totalMetaNode_) = totalMetaNode.tryMul(1 ether);
            require(success2, "overflow");
            // 再除以池中的质押代币总量 stSupply ，得到每单位质押代币的新增奖励 totalMetaNode_ 。
            (success2, totalMetaNode_) = totalMetaNode_.tryDiv(stSupply);
            require(success2, "overflow");
            // 将新增奖励 totalMetaNode_ 累加到池的 accMetaNodePerST 中。
            (bool success3, uint256 accMetaNodePerST) = pool_.accMetaNodePerST.tryAdd(totalMetaNode_);
            require(success3, "overflow");
            pool_.accMetaNodePerST = accMetaNodePerST;
        }

        pool_.lastRewardBlock = block.number;

        emit UpdatePool(_pid, pool_.lastRewardBlock, totalMetaNode);
    }

    /**
     * @notice 更新所有池的奖励变量。小心汽油消耗！
     */
    function massUpdatePools() public {
        uint256 length = pool.length;
        for (uint256 pid = 0; pid < length; pid++) {
            updatePool(pid);
        }
    }

    /**
     * @notice 存入 ETH 以获得 MetaNode 奖励
     */
    function depositETH() public whenNotPaused() payable {
        Pool storage pool_ = pool[ETH_PID];
        require(pool_.stTokenAddress == address(0x0), "invalid staking token address");

        uint256 _amount = msg.value;
        require(_amount >= pool_.minDepositAmount, "deposit amount is too small");

        _deposit(ETH_PID, _amount);
    }

    /**
     * @notice 存入质押代币以获得 MetaNode 奖励
     *  在存款之前，用户需要批准此合约才能花费或转移他们的质押代币
     *
     * @param _pid       Id of the pool to be deposited to
     * @param _amount    Amount of staking tokens to be deposited
     */
    function deposit(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) {
        require(_pid != 0, "deposit not support ETH staking");
        Pool storage pool_ = pool[_pid];
        require(_amount > pool_.minDepositAmount, "deposit amount is too small");

        if(_amount > 0) {
            IERC20(pool_.stTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        }

        _deposit(_pid, _amount);
    }

    /**
     * @notice 取消质押代币
     * 用户从指定质押池中取消质押代币，将代币从质押状态转为待提取状态（需等待解锁）。
     * @param _pid       Id of the pool to be withdrawn from
     * @param _amount    amount of staking tokens to be withdrawn
     */
    function unstake(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused() {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        require(user_.stAmount >= _amount, "Not enough staking token balance");

        // 更新池的奖励状态
        updatePool(_pid);

        // 计算并分配用户待领取的奖励。 (质押量 × 单位奖励) - 已结算奖励
        uint256 pendingMetaNode_ = user_.stAmount * pool_.accMetaNodePerST / (1 ether) - user_.finishedMetaNode;

        if(pendingMetaNode_ > 0) {
            user_.pendingMetaNode = user_.pendingMetaNode + pendingMetaNode_;
        }

        if(_amount > 0) {
            // 减少用户的质押量 user_.stAmount 
            user_.stAmount = user_.stAmount - _amount;
            // 创建提取请求 UnstakeRequest 
            user_.requests.push(UnstakeRequest({
                amount: _amount, // 取消质押的数量。
                unlockBlocks: block.number + pool_.unstakeLockedBlocks // 解锁区块高度（当前区块 + 锁定区块数 unstakeLockedBlocks ）。
            }));
        }

        // 减少池的总质押量 stTokenAmount    
        pool_.stTokenAmount = pool_.stTokenAmount - _amount;
        // finishedMetaNode = 当前质押量 × 单位奖励 ，表示用户的最新奖励结算点。
        user_.finishedMetaNode = user_.stAmount * pool_.accMetaNodePerST / (1 ether);

        emit RequestUnstake(msg.sender, _pid, _amount);
    }

    /**
     * @notice 提取解锁未质押金额
     * 用户从指定质押池中提取已解锁的质押代币（或 ETH）。
     *
     * @param _pid       Id of the pool to be withdrawn from
     */
    function withdraw(uint256 _pid) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused() {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        uint256 pendingWithdraw_;
        uint256 popNum_;
        // 遍历用户的提取请求列表，筛选已解锁的请求。
        for (uint256 i = 0; i < user_.requests.length; i++) {
            if (user_.requests[i].unlockBlocks > block.number) {
                break; // 遇到第一个未解锁的请求时终止遍历（因为请求是按解锁时间排序的）。
            }
            // 计算可提取的总金额。
            pendingWithdraw_ = pendingWithdraw_ + user_.requests[i].amount;
            popNum_++;
        }
        // 更新用户的请求列表（移除已处理的请求）。
        for (uint256 i = 0; i < user_.requests.length - popNum_; i++) {
            user_.requests[i] = user_.requests[i + popNum_]; // 前移未处理的请求
        }

        for (uint256 i = 0; i < popNum_; i++) {
            user_.requests.pop(); // 移除已处理的请求，调用 pop 移除数组末尾的空位。
        }

        // 将代币（或 ETH）转账给用户。
        if (pendingWithdraw_ > 0) {
            if (pool_.stTokenAddress == address(0x0)) {
                _safeETHTransfer(msg.sender, pendingWithdraw_);
            } else {
                IERC20(pool_.stTokenAddress).safeTransfer(msg.sender, pendingWithdraw_);
            }
        }

        emit Withdraw(msg.sender, _pid, pendingWithdraw_, block.number);
    }

    /**
     * @notice 领取 MetaNode 代币奖励
     *
     * @param _pid       Id of the pool to be claimed from
     */
    function claim(uint256 _pid) public whenNotPaused() checkPid(_pid) whenNotClaimPaused() {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        updatePool(_pid);

        uint256 pendingMetaNode_ = user_.stAmount * pool_.accMetaNodePerST / (1 ether) - user_.finishedMetaNode + user_.pendingMetaNode;

        if(pendingMetaNode_ > 0) {
            user_.pendingMetaNode = 0;
            _safeMetaNodeTransfer(msg.sender, pendingMetaNode_);
        }

        user_.finishedMetaNode = user_.stAmount * pool_.accMetaNodePerST / (1 ether);

        emit Claim(msg.sender, _pid, pendingMetaNode_);
    }

    // ************************************** INTERNAL FUNCTION **************************************

    /**
     * @notice 用户向指定质押池存入代币（或 ETH），并更新其奖励状态。
     *
     * @param _pid       质押池的 ID
     * @param _amount    质押的代币数量（单位为代币的最小精度，如 wei ）。
     */
    function _deposit(uint256 _pid, uint256 _amount) internal {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        // 更新池的奖励状态
        updatePool(_pid);

        // 计算并分配用户待领取的奖励
        if (user_.stAmount > 0) {
            // // 计算用户当前质押量应得的累积奖励，单位为 wei 
            // uint256 accST = user_.stAmount.mulDiv(pool_.accMetaNodePerST, 1 ether);
            (bool success1, uint256 accST) = user_.stAmount.tryMul(pool_.accMetaNodePerST);
            require(success1, "user stAmount mul accMetaNodePerST overflow");
            (success1, accST) = accST.tryDiv(1 ether);
            require(success1, "accST div 1 ether overflow");
            
            // 计算待领取的奖励 = 累积奖励 - 已结算奖励
            (bool success2, uint256 pendingMetaNode_) = accST.trySub(user_.finishedMetaNode);
            require(success2, "accST sub finishedMetaNode overflow");

            // 将待领取奖励添加到用户的 pendingMetaNode
            if(pendingMetaNode_ > 0) {
                (bool success3, uint256 _pendingMetaNode) = user_.pendingMetaNode.tryAdd(pendingMetaNode_);
                require(success3, "user pendingMetaNode overflow");
                user_.pendingMetaNode = _pendingMetaNode;
            }
        }

        // 增加用户的质押量
        if(_amount > 0) {
            (bool success4, uint256 stAmount) = user_.stAmount.tryAdd(_amount);
            require(success4, "user stAmount overflow");
            user_.stAmount = stAmount;
        }

        // 增加池的总质押量
        (bool success5, uint256 stTokenAmount) = pool_.stTokenAmount.tryAdd(_amount);
        require(success5, "pool stTokenAmount overflow");
        pool_.stTokenAmount = stTokenAmount;

        // 更新用户的奖励结算状态
        // user_.finishedMetaNode = user_.stAmount.mulDiv(pool_.accMetaNodePerST, 1 ether);
        (bool success6, uint256 finishedMetaNode) = user_.stAmount.tryMul(pool_.accMetaNodePerST);
        require(success6, "user stAmount mul accMetaNodePerST overflow");

        (success6, finishedMetaNode) = finishedMetaNode.tryDiv(1 ether);
        require(success6, "finishedMetaNode div 1 ether overflow");

        user_.finishedMetaNode = finishedMetaNode;

        emit Deposit(msg.sender, _pid, _amount);
    }

    /**
     * @notice Safe MetaNode transfer function, just in case if rounding error causes pool to not have enough MetaNodes
     *
     * @param _to        Address to get transferred MetaNodes
     * @param _amount    Amount of MetaNode to be transferred
     */
    function _safeMetaNodeTransfer(address _to, uint256 _amount) internal {
        uint256 MetaNodeBal = MetaNode.balanceOf(address(this));

        if (_amount > MetaNodeBal) {
            MetaNode.transfer(_to, MetaNodeBal);
        } else {
            MetaNode.transfer(_to, _amount);
        }
    }

    /**
     * @notice Safe ETH transfer function
     *
     * @param _to        Address to get transferred ETH
     * @param _amount    Amount of ETH to be transferred
     */
    function _safeETHTransfer(address _to, uint256 _amount) internal {
        (bool success, bytes memory data) = address(_to).call{
            value: _amount
        }("");

        require(success, "ETH transfer call failed");
        if (data.length > 0) {
            require(
                abi.decode(data, (bool)),
                "ETH transfer operation did not succeed"
            );
        }
    }
}