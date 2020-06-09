// SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract THXToken is ERC20, AccessControl {
    // Transfer Gateway contract address
    address public gateway;
    // Create a new role identifier for the minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(address => mapping(address => uint256)) private _allowedDeposits;

    constructor(address _gateway, address minter)
        public
        ERC20("THXToken", "THX")
    {
        gateway = _gateway;

        // Grant the minter role to a specified account
        _setupRole(MINTER_ROLE, minter);
    }

    function mint(address to, uint256 amount) public {
        // Check that the calling account has the minter role
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _mint(to, amount);
    }

    function approveDeposit(
        address from,
        address to,
        uint256 value
    ) public returns (bool) {
        // Check that the to address is set
        require(to != address(0), "To address is not set");

        _allowedDeposits[from][to] = value;
        emit Approval(from, to, value);
        return true;
    }

    function transferDeposit(
        address from,
        address to,
        uint256 value
    ) public returns (bool) {
        _allowedDeposits[from][to] = _allowedDeposits[from][to].sub(value);
        _transfer(from, to, value);
        emit Approval(from, to, _allowedDeposits[from][to]);
        return true;
    }

    // Called by the gateway contract to mint tokens that have been deposited to the Mainnet gateway.
    function mintToGateway(uint256 _amount) public {
        require(msg.sender == gateway, "Caller is not the Gateway");
        _mint(gateway, _amount);
    }
}
