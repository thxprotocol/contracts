pragma solidity ^0.5.0;

import "../Roles.sol";

contract MemberRole {
    using Roles for Roles.Role;

    event MemberAdded(address indexed account);
    event MemberRemoved(address indexed account);

    Roles.Role private _members;

    constructor () internal {
        _addMember(msg.sender);
    }

    modifier onlyMember() {
        require(isMember(msg.sender));
        _;
    }

    function isMember(address account) public view returns (bool) {
        return _members.has(account);
    }

    function addMember(address account) public onlyMember {
        _addMember(account);
    }

    function renounceMember() public {
        _removeMember(msg.sender);
    }

    function _addMember(address account) internal {
        _members.add(account);
        emit MemberAdded(account);
    }

    function _removeMember(address account) internal {
        _members.remove(account);
        emit MemberRemoved(account);
    }
}
