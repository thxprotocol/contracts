// contracts/RewardPool.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

import "./access/Roles.sol";

contract RewardPool is Initializable, OwnableUpgradeSafe, Roles {
    using SafeMath for uint256;

    function initialize(address _owner) public initializer {
        __Ownable_init();
        __Roles_init(_owner);

        transferOwnership(_owner);
    }
}
