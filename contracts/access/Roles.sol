// contracts/AssetPool.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/utils/EnumerableSet.sol';

contract Roles is AccessControlUpgradeSafe {
    bytes32 public constant MEMBER_ROLE = keccak256('MEMBER_ROLE');
    bytes32 public constant MANAGER_ROLE = keccak256('MANAGER_ROLE');

    EnumerableSet.AddressSet _members;
    EnumerableSet.AddressSet _managers;

    event MemberAdded(address account);
    event MemberRemoved(address account);
    event ManagerAdded(address account);
    event ManagerRemoved(address account);

    modifier onlyMember() {
        require(
            hasRole(MEMBER_ROLE, _msgSender()) || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            'caller is not a member or role admin'
        );
        _;
    }

    modifier onlyManager() {
        require(
            hasRole(MANAGER_ROLE, _msgSender()) || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            'caller is not a manager or role admin'
        );
        _;
    }

    /**
     * @dev Initializes the asset pool and sets the owner. Called when contract upgrades are available.
     * @param _owner Address of the owner of the asset pool
     */
    function __Roles_init(address _owner) public {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(MEMBER_ROLE, _owner);
        _setupRole(MANAGER_ROLE, _owner);
    }

    /**
     * @dev Grants member role and adds address to member list
     * @param _account A valid address
     */
    function addMember(address _account) public onlyMember {
        grantRole(MEMBER_ROLE, _account);
        _members.add(_account);
        emit MemberAdded(_account);
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
        _members.remove(_account);
        emit MemberRemoved(_account);
    }

    /**
     * @dev Grants manager role and adds address to manager list
     * @param _account A member address
     */
    function addManager(address _account) public onlyManager {
        grantRole(MANAGER_ROLE, _account);
        _managers.add(_account);
        emit ManagerAdded(_account);
    }

    /**
     * @dev Verifies the account has a MANAGER_ROLE
     * @param _account Address of the owner of the asset pool
     */
    function isManager(address _account) public view returns (bool) {
        return hasRole(MANAGER_ROLE, _account);
    }

    /**
     * @dev Revokes role and sets manager address to false in list.
     * @param _account Address of the owner of the asset pool
     */
    function removeManager(address _account) public onlyManager {
        revokeRole(MANAGER_ROLE, _account);
        _managers.remove(_account);
        emit ManagerRemoved(_account);
    }
}
