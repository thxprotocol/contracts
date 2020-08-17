# THX - Reward Pool

## Abstract

This repository holds the smart contracts used by THX Wallet. This document outlines the models used in the contract layer and describes the data that is stored. For a detailed explanation of the workings you should dive into the code and read the documentation for the methods.

## Features

-   [x] Make a deposit
-   [x] Claim a reward
-   [x] Propose a reward
-   [x] Approve a reward proposal
-   [ ] Reject a reward proposal
-   [x] Withdraw a reward
-   [x] Create a reward rule proposal
-   [x] Approve a reward rule proposal
-   [ ] Reject a reward rule proposal
-   [x] Add a member
-   [x] Revoke member role
-   [x] Add a manager
-   [x] Revoke manager role

## Data Storage

This section documents user data that is stored in the smart contracts on the loom network and should clarify why it needs to be stored.

## Events

```
event Withdrawn(address indexed beneficiary, uint256 reward)
```

```
event RewardRulePollCreated(uint256 id, uint256 proposal, address sender)
```

```
event RewardRulePoll
```

```
event RewardRuleUpdated(uint256 id, RuleState state, uint256 amount)
```

```
event RewardRulePollFinished(uint256 id, uint256 amount)
```

```
event RewardPollFinished(address reward, bool agree)
```

_More should be added to this list..._

## Methods

```
// Initializes the reward pool and sets the owner. Called when contract upgrades are available.
function initialize(address _owner, address _tokenAddress) public initializer
```

```
// Set the duration for a reward poll.
function setRewardPollDuration(uint256 _duration) public
```

```
// Set the duration for a reward poll.upgrades are available.
function setRewardPollDuration(uint256 _duration) public
```

_More should be added to this list..._

## OpenZeppelin

This sections described the Open Zeppelin standard contracts that are used in the THX contract layer.

### [ERC20 Token](https://docs.openzeppelin.com/contracts/3.x/erc20)

THXToken inherits all logic from this standard contract and adds some logic for integration with the Transfer Gateway. THXTokenRinkeby is the ERC20 contract that is actually deployed on Ethereum networks (Rinkeby as of today).

### [Ownable](https://docs.openzeppelin.com/contracts/3.x/access-control)

RewardPool is derived from the Ownable smart contract and inherits ownership features. Usefull when transfering ownership of a pool and restricting breaking mutations to the smart contracts. Also a necessity for the upgradability of the contract. [Read more about upgradability](#Upgrades).

### [Access Control](https://docs.openzeppelin.com/contracts/3.x/access-control)

AccessControl is used to create MEMBER_ROLE and MANAGER_ROLE. MEMBER_ROLE is used to identify members of a reward pool and allow them to claim rewards and vote on reward rule proposals.
