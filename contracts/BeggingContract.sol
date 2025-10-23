// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;  // 使用更具体的版本，避免未来兼容性问题

contract BeggingContract {
    event DonationReceived(address indexed donor, uint256 amount);
    event Withdrawal(address indexed owner, uint256 amount);

    address public immutable owner;  // `immutable` 更省气，且更安全
    mapping(address => uint256) public donationAmount;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    // 捐赠函数：更新累计捐赠金额
    function donate() external payable {
        require(msg.value > 0, "Donation amount must be > 0");
        donationAmount[msg.sender] += msg.value;
        emit DonationReceived(msg.sender, msg.value);
    }

    // 提现函数
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Transfer failed");
        emit Withdrawal(owner, balance);
    }
}