# THX Reward System - Smart Contract Layer

## Abstract

This repository holds the smart contracts used by THX Wallet. This document outlines the models used in the contract layer and describes the data that is stored. For a detailed explanation of the workings you should dive into the code and read the documentation for the methods.

## OpenZeppelin

### [ERC20 Token](https://docs.openzeppelin.com/contracts/3.x/erc20)

THXToken inherits all logic from this standard contract and adds some logic for integration with the Transfer Gateway. THXTokenRinkeby is the ERC20 contract that is actually deployed on Ethereum networks (Rinkeby as of today).

### [Ownable](https://docs.openzeppelin.com/contracts/3.x/access-control)
RewardPool is derived from the Ownable smart contract and inherits ownership features. Usefull when transfering ownership of a pool and restricting breaking mutations to the smart contracts. Also a necessity for the upgradability of the contract. [Read more about upgradability](#Upgrades).

### [Access Control](https://docs.openzeppelin.com/contracts/3.x/access-control)
AccessControl is used to create MEMBER_ROLE and MANAGER_ROLE. MEMBER_ROLE is used to identify members of a reward pool and allow them to claim rewards and vote for reward rule proposals.  

## Data Storage

This section documents user data that is stored in the smart contracts on the loom network and should clarify why it needs to be stored.
