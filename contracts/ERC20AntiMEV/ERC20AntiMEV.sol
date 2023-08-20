// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Extension of the ERC20 token contract to anti-sandwiching.
 *
 * Deployers of the ERC20 token with this extension will have the capacity to prevent accounts
 * and contracts from performing sandwich attacks in the same block
 *
 */
contract ERC20AntiMEV is ERC20, Ownable {
    mapping(address => uint256) public tracker; // Tracks when accounts/contracts last sent/received the token
    mapping(address => bool) public excused; // Accounts/contracts which are excused from this mechanism
    bool public blockActive = true; // Determines whether this extension is active

    constructor(
        uint256 _initialSupply,
        string memory _name
    ) ERC20(_name, _name) {
        _mint(msg.sender, _initialSupply);
    }

    /**
     * @dev setExcused 
     * @param _address address to be excused or have their privilege revoked
     * @param _state the desired state of privilege for the address
     */
    function setExcused(address _address, bool _state) external onlyOwner {
        excused[_address] = _state;
    }

    /**
     * @dev setActive
     * @param _state determines whether this extension is active or not
     */
    function setActive(bool _state) external onlyOwner {
        blockActive = _state;
    }

    /**
     * @dev _beforeTokenTransfer
     * 
     * Extension of the base _beforeTokenTransfer hook, checks if the sender and receiver have
     * transfered tokens in the same block, if this is the case, the transaction will revert.
     * The exception to this is if an address has been added to the excusable mapping. However,
     * restrictions still apply if the sender or recipient is not on this list.
     * 
     */
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
