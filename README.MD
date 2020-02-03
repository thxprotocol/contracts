# THX Reward System - Smart Contract Layer

## Introduction

This repository holds the smart contracts used by THX Wallet. This document outlines the models used in the contract layer and describes the data that is stored.

For a detailed explanation of the workings you should dive into the code and read the documentation for the methods.

## Repository outline
* Access
  * Roles
    * ManagerRole.sol
    * MinterRole.sol
  * Roles.sol
* Math
  * Math.sol
  * SafeMath.sol
* Poll
  * Polls
    * RulePoll.sol
  * BasePoll.sol
* Reward
  * Reward.sol
* Rule
  * Rules.sol
* Token
  * ERC20
    * ERC20.sol
    * ERC20Mintable.sol
    * IERC20.sol
* IRewardPool.sol
* RewardPool.sol
* THXToken.sol
* THXTokenRinkeby.sol (only contract deployed on main net)

## Models
This section documents user data that is stored in the smart contracts on the loom network.

### MemberRole
```
members[address => bool]
```
This list is used to determine if an address is a member of the pool.

### BasePoll
```
votesByAddress[address = Vote] = Vote(
	uint256 time,
	uint256 weight,
	/bool/ agree,
)
```
This list is used to retrieve information about a vote that is cast by a certain address.

### Reward
```
uint256 id // Might be removed
```
This is the uniquer identifier of the reward. It can be referenced by other smart contracts.

```
uint256 rule
```
The rule is used as a readable string describing the reward rule.

```
address beneficiary
```
The beneficiary is the receiver of the reward amount.

```
uint256 amount
```
The amount equals the amount the beneficiary can withdraw after approval of the reward.

```
RewardState state
```
The reward state (Pending, Approved, Rejected, Withdrawn) changes while the reward is processed.

* Pending: The reward is claimed by the beneficiary
* Approved: The reward is approved by a manager
* Rejected: The reward is rejected by a manager
* Withdrawn: The reward is withdrawn by the beneficiary

```
uint256 created
```
The timestamp of the mined block that included the transaction the created the the reward.

### RewardPool (MemberRole, Rules, BasePoll)
```
rewards[address => Reward] = Reward() // See the Reward model for the contents of the model.
```
This list contains the reward per address. It is used to retrieve information about rewards .

```
deposits[address => Deposit] = Deposit(
    address sender,
    uint256 amount,
    uint256 created
    )
```
This list contains the deposits per address. It is used to retrieve historical data about incoming token transfers for the reward pool in faster way than crawling back in time through all blocks and look for events.

```
withdrawels[address => Withdrawel] = Withdrawel(
    address receiver,
    uint256 amount,
    uint256 created
    )
```
This list contains the withdrawels per address. It is used to retrieve historical data about outgoing token transfers for the reward pool in faster way than crawling back in time through all blocks and look for events.

## Events
This section documents the events that are stored in transactions mined by blocks in the loom network.

```
Transfer
```
Emits when a token transaction occurs.
```
Deposited
```
Emits when a deposit to the reward pool balance is made.
```
Withdrawn
```
Emits when a the reward size is withdrawn from the pool balance.
```
RewardStateChanged
```
Emits when the state of Reward changes. Used to notify managers to verify the reward or to notify members to claim the reward size.
```
RewardPollCreated
```
Emits when a Reward is claimed. Used to notify managers to start verifying the reward.
```
RewardPollFinished // Might be removed
```
Emits when a Reward Poll is finished. Used to notify the owner to withdraw the reward.
```
ManagerAdded
```
Emits when a manager is added to the reward pool. Used to notify members and other managers.
```
ManagerRemoved
```
Emits when a manager is removed from the reward pool. Used to notify members and other managers.
```
MemberAdded
```
Emits when a member is added to the reward pool. Used to notify members and other managers.
```
MemberRemoved
```
Emits when a member is removed from the reward pool. Used to notify members and other managers.