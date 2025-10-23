// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

/*
✅ 作业 1：ERC20 代币
任务：参考 openzeppelin-contracts/contracts/token/ERC20/IERC20.sol实现一个简单的 ERC20 代币合约。要求：
合约包含以下标准 ERC20 功能：
balanceOf：查询账户余额。
transfer：转账。
approve 和 transferFrom：授权和代扣转账。
使用 event 记录转账和授权操作。
提供 mint 函数，允许合约所有者增发代币。
提示：
使用 mapping 存储账户余额和授权信息。
使用 event 定义 Transfer 和 Approval 事件。
部署到sepolia 测试网，导入到自己的钱包
*/
//提供安全的数学运算函数
library safeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

//定义ERC20代币标准的函数规范
interface IERC20 {
    // 获取合约地址
    function getAddress() external view returns (address);
    // 获取代币发行总量
    function totalSupply() external view returns (uint256);
    // 根据地址获取代币的余额
    function balanceOf(address account) external view returns (uint256);
    // 代理可转移的代币数量
    function allowance(address owner, address supender) external view returns (uint256);

    // 转账
    function transfer(address recipient, uint256 amount) external returns (bool);
    // 设置代理能转账的金额
    function approve(address owner, address spender, uint256 amount) external returns (bool);
    // 转账
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    //挖矿
    function mint(uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// ERC20代币的具体实现
contract ERC20Basic is IERC20 {
    string public constant name = "ERC-NNChain"; // 代币名称
    string public constant symbol = "ERC-NN"; // 代币简称
    uint8 public constant decimals = 18;
    address createOwner;
    mapping(address => uint256) balances; // 地址对应的余额数量
    //仅仅是设定数量，这个值并不影响发行的代币的数量
    mapping(address => mapping(address => uint256)) allowedBalence; // 代理商能处理的代币数量
    //uint256 totalSupply_ = 10 ether; // 发行数量，ether指的是单位，类似吨，也可以使用8个0
    uint256 totalSupply_; 
    //允许将库的函数绑定到特定的数据类型，使得库函数可以直接作用于该数据类型的变量，简化函数调用。
    using safeMath for uint256;


    constructor () {
        //msg.sender就是DEX地址
        //msg.sender永远是直接调用当前函数的地址
        createOwner = msg.sender;
        totalSupply_ = 1000000 * 10 ** decimals; 
        //将代币放入DEX合约地址中
        balances[createOwner] = totalSupply_; // 将代币分发给创建者

    } 
    //
    function mint (uint256 amount) external returns (bool){
        require(amount >0,"You need to mint more Ethoer");
        //将增发代币发送给合约创建者
        balances[createOwner] += amount;
        //更新发行总量
        totalSupply_ += amount;
        return true;
    }
     // 获取交易所地址
    function getAddress() external view returns (address){
        return address(this); // 当前合约的地址
    }
    // 获取交易所代币发行总量
    function totalSupply() external view returns (uint256){
        return totalSupply_;
    }

    // 在交易所中根据用户地址获取代币的余额
    function balanceOf(address tokenOwner) public override view returns (uint256){
        return balances[tokenOwner]; // 根据地址获取余额
    }

    // 将当前用户的代币转账给其他地址的用户 
    function transfer(address receiver, uint256 amount) public override returns (bool){
        require(amount <= balances[msg.sender]);
        // 实际上编译器会将其转换为：safeMath.sub(balances[msg.sender], amount)
        //msg.sender永远是直接调用当前函数的地址
        balances[msg.sender] = balances[msg.sender].sub(amount);
        balances[receiver] = balances[receiver].add(amount);
        emit Transfer(msg.sender, receiver, amount);
        return true;
    }

    /*
    * 设置代理能转账的金额
    * @p owner 代币所有者地址
    * @p delegate 操作代币的合约地址
    * @p amount 金额
    */
    function approve(address owner, address delegate, uint256 amount) external returns (bool){
        require(amount >0,"You need more Ethoer to approve");
        allowedBalence[owner][delegate] = amount;
        emit Approval(owner, delegate, amount);
        return true;
    }

    /*
    * 查询代理金额
    *
    * @p owner 代币所有者地址
    * @p delegate 操作代币的合约地址
    */
    function allowance(address owner, address delegate) external view returns (uint256){
        return allowedBalence[owner][delegate];
    }

    // 转账
    function transferFrom(address from, address to, uint256 amount) external returns (bool){
        require(amount <= balances[from],"not ength balances");
        require(amount <= allowedBalence[from][msg.sender],"not ength allowedBalence");

        balances[from] = balances[from].sub(amount);
        allowedBalence[from][to] = allowedBalence[from][to].sub(amount);
        balances[to] = balances[to].add(amount);
        emit Transfer(from, to, amount);
        return true;
    }
}

//去中心化交易所，提供代币买卖功能
contract DEX {
    event Bought(uint256 amount);
    event Sold(uint256 amount);
     
    IERC20 public token;

    constructor () {
        token = new ERC20Basic();
    }

    // 买入 从合约购买代币
    function buy() payable public {
        uint256 amountTobuy = msg.value; //传入以太坊
        uint256 dexBalance = token.balanceOf(address(this)); //此合约中自己创建代币的数量
        require(amountTobuy > 0 , "You need to send some Ethoer"); // amountTobuy 必须传入以太，使用以太购买此代币
        require(amountTobuy <= dexBalance, "Not enough tokens in the reserve"); // 合约中代币的数量要大于要购买的量
        //msg.sender就是用户地址
        token.transfer(msg.sender, amountTobuy);
        emit Bought(amountTobuy);
    }
    
    //向合约出售代币
    function sell(uint256 amount) public {
        require(amount > 0, "You need to sell at least some tokens."); // 卖出数量要大于0
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= amount, "check the token allowance");
        token.transferFrom(msg.sender, address(this), amount);

        emit Sold(amount);
    }

    //获得当前合约的ERC-xin代币余额 非默认机制
    function getDexBalance() public view returns(uint256) {
        return token.balanceOf(address(this));
    }

    //获得当前合约的ETH以太币余额 默认机制 合约默认带有以太币余额
    function getDexEthBalance() public view returns(uint256) {
        return address(this).balance;  // 自动存在的ETH余额
    }

    //获得当前用户的ERC-xin代币余额  非默认机制
    function getOwnerBalance() public view returns(uint256) {
        return token.balanceOf(msg.sender);
    }

    //获得当前合约地址
    function getAddress() public view returns (address) {
        return address(this);
    }

    //获得ERC20合约地址
    function getTokenAddress() public view returns (address) {
        return token.getAddress();
    }

    function getTotalSupply() public view returns (uint256) {
        return token.totalSupply();
    }

    function getSenderAddress() public view returns (address) {
        return address(msg.sender);
    }

    function getAllowance() public view returns (uint256) {
        uint256 allowance = token.allowance(msg.sender, address(this));
        return allowance;
    }

    // 授权当前合约转移代币数量 
    // 重点是当前合约 approve是授权给当前的合约可以转移的数量
    // 也就是授权给交易所可以交易的数量 因为合约在交易所的连上运行
    function approve(uint256 amount) public returns(bool) {
        bool isApprove = token.approve(msg.sender, address(this), amount);
        return isApprove;
    }
}