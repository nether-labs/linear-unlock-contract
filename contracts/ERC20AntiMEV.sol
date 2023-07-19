// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "hardhat/console.sol";

contract ERC20AntiMEV is ERC20, Ownable {
    mapping(address => uint256) public tracker;
    mapping(address => bool) public excused;
    bool blockActive = true;

    constructor(
        uint256 _initialSupply,
        string memory _name
    ) ERC20(_name, _name) {
        _mint(msg.sender, _initialSupply);
    }

    function setExcused(address _address, bool _state) external onlyOwner {
        excused[_address] = _state;
    }

    function setSandwichBlock(bool _state) external onlyOwner {
        blockActive = _state;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (blockActive) {
            require(
                excused[from] || tracker[from] != block.timestamp,
                "Sender in same block"
            );
            require(
                excused[to] || tracker[to] != block.timestamp,
                "Recipient in same block"
            );

            tracker[to] = tracker[from] = block.timestamp;
        }
    }
}
