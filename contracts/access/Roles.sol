// contracts/RewardPool.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/utils/EnumerableSet.sol';

contract Roles is AccessControlUpgradeSafe {
    bytes32 public constant MEMBER_ROLE = keccak256('MEMBER_ROLE');
    bytes32 public constant MANAGER_ROLE = keccak256('MANAGER_ROLE');

    EnumerableSet.AddressSet members;
    EnumerableSet.AddressSet managers;

    modifier onlyMember() {
        require(hasRole(MEMBER_ROLE, msg.sender), 'caller is not a member');
        _;
    }

    modifier onlyManager() {
        require(hasRole(MANAGER_ROLE, msg.sender), 'caller is not a manager');
        _;
    }

    /**
     * @dev Initializes the reward pool and sets the owner. Called when contract upgrades are available.
     * @param _owner Address of the owner of the reward pool
     */
    function __Roles_init(address _owner) public {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(MEMBER_ROLE, _owner);
        _setupRole(MANAGER_ROLE, _owner);
    }

    /**
     * @dev Grants manager role and adds address to manager list
     * @param _account A valid address
     */
    function addMember(address _account) public {
        grantRole(MEMBER_ROLE, _account);
        members.add(_account);
    }

    /**
     * @dev Verifies the account has a MEMBER_ROLE
     * @param _account A member address
     */
    function isMember(address _account) public view returns (bool) {
        return hasRole(MEMBER_ROLE, _account);
    }

    /**
     * @dev Revokes role and sets member address to false in list.
     * @param _account A member address
     */
    function removeMember(address _account) public onlyManager {
        revokeRole(MEMBER_ROLE, _account);
        members.remove(_account);
    }

    /**
     * @dev Grants manager role and adds address to manager list
     * @param _account A member address
     */
    function addManager(address _account) public onlyManager {
        grantRole(MANAGER_ROLE, _account);
        members.add(_account);
    }

    /**
     * @dev Verifies the account has a MANAGER_ROLE
     * @param _account Address of the owner of the reward pool
     */
    function isManager(address _account) public view returns (bool) {
        return hasRole(MANAGER_ROLE, _account);
    }

    /**
     * @dev Revokes role and sets manager address to false in list.
     * @param _account Address of the owner of the reward pool
     */
    function removeManager(address _account) public onlyManager {
        revokeRole(MANAGER_ROLE, _account);
        members.remove(_account);
    }
}
