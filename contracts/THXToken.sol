// contracts/THXToken.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract THXToken is ERC20, AccessControl {
    // Transfer Gateway contract address
    address public gateway;
    bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');

    mapping(address => mapping(address => uint256)) private _allowedDeposits;

    constructor(address _gateway, address minter) public ERC20('THXToken', 'THX') {
        gateway = _gateway;

        _setupRole(MINTER_ROLE, minter);
    }

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender), 'IS_NOT_MINTER');
        _mint(to, amount);
    }

    // Called by the gateway contract to mint tokens that have been deposited to the Mainnet gateway.
    function mintToGateway(uint256 _amount) public {
        require(msg.sender == gateway, 'IS_NOT_GATEWAY');
        _mint(gateway, _amount);
    }
}
