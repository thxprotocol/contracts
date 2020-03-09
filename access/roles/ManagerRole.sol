pragma solidity ^0.5.0;

import "../Roles.sol";

contract ManagerRole {
    using Roles for Roles.Role;

    event ManagerAdded(address indexed account);
    event ManagerRemoved(address indexed account);

    Roles.Role public managers;

    constructor () internal {
        _addManager(msg.sender);
    }

    modifier onlyManager() {
        require(isManager(msg.sender));
        _;
    }

    function isManager(address account) public view returns (bool) {
        return managers.has(account);
    }

    function addManager(address account) public onlyManager {
        _addManager(account);
    }

    function renounceManager() public {
        _removeManager(msg.sender);
    }

    function _addManager(address account) internal {
        managers.add(account);
        emit ManagerAdded(account);
    }

    function _removeManager(address account) internal {
        managers.remove(account);
        emit ManagerRemoved(account);
    }
}
