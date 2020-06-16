// contracts/RewardPool.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";

contract Roles is AccessControlUpgradeSafe {
    bytes32 public constant MEMBER_ROLE = keccak256("MEMBER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    function __Roles_init(address _owner) public {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(MEMBER_ROLE, _owner);
        _setupRole(MANAGER_ROLE, _owner);
    }

    function addMember(address account) public {
        grantRole(MEMBER_ROLE, account);
    }

    function isMember(address account) public view returns (bool) {
        return hasRole(MEMBER_ROLE, account);
    }

    function removeMember(address account) public {
        revokeRole(MEMBER_ROLE, account);
    }

    function addManager(address account) public {
        grantRole(MANAGER_ROLE, account);
    }

    function isManager(address account) public view returns (bool) {
        return hasRole(MANAGER_ROLE, account);
    }

    function removeManager(address account) public {
        revokeRole(MANAGER_ROLE, account);
    }
}
