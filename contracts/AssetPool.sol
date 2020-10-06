// contracts/AssetPool.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';

import './access/Roles.sol';
import './poll/WithdrawPoll.sol';
import './poll/RewardPoll.sol';

contract AssetPool is Initializable, OwnableUpgradeSafe, Roles {
    using SafeMath for uint256;

    struct Reward {
        uint256 id;
        uint256 withdrawAmount;
        uint256 withdrawDuration;
        RewardState state;
        RewardPoll poll;
        uint256 updated;
    }

    mapping(address => bool) public polls;
    Reward[] public rewards;
    WithdrawPoll[] public withdraws;

    uint256 public proposeWithdrawPollDuration = 0;
    uint256 public rewardPollDuration = 0;

    IERC20 public token;

    /*==== IMPORTANT: Do not alter (only extend) the storage layout above this line! ====*/

    enum RewardState { Disabled, Enabled }

    event Withdrawn(address indexed member, uint256 reward);
    event Deposited(address indexed member, uint256 amount);
    event RewardPollCreated(address indexed member, address poll, uint256 id, uint256 proposal);
    event WithdrawPollCreated(address indexed member, address poll);

    /**
     * @dev Initializes the asset pool and sets the owner. Called when contract upgrades are available.
     * @param _owner Address of the owner of the asset pool
     * @param _tokenAddress Address of the ERC20 token used for this pool
     */
    function initialize(address _owner, address _tokenAddress) public initializer {
        __Ownable_init();
        __Roles_init(_owner);

        transferOwnership(_owner);

        token = IERC20(_tokenAddress);
        // TODO check balance of token (should be prefilled)
        // should be refilled by erc20 transfer function with _tokenAddress
    }

    modifier useNonce(address _member, uint256 _nonce) {
        validateNonce(_member, _nonce);
        _;
    }

    mapping(address => uint256) public memberNonces;

    /**
     * @dev Get the latest nonce of a given voter
     * @param _member Address of the voter
     */
    function getLatestNonce(address _member) public view returns (uint256) {
        return memberNonces[_member];
    }

    /**
     * @dev Validate a given nonce, reverts if nonce is not right
     * @param _member Address of the voter
     * @param _nonce Nonce of the voter
     */
    function validateNonce(address _member, uint256 _nonce) public {
        require(polls[msg.sender] || msg.sender == owner(), 'UNEXPECTED_SENDER');
        uint256 lastNonce = memberNonces[_member];
        require(lastNonce + 1 == _nonce, 'INVALID_NONCE');
        memberNonces[_member] = _nonce;
    }

    /**
     * @dev Set the duration for a withdraw poll poll.
     * @param _duration Duration in seconds
     */
    function setProposeWithdrawPollDuration(uint256 _duration) public onlyOwner {
        proposeWithdrawPollDuration = _duration;
    }

    /**
     * @dev Set the reward poll duration
     * @param _duration Duration in seconds
     */
    function setRewardPollDuration(uint256 _duration) public onlyOwner {
        rewardPollDuration = _duration;
    }

    /**
     * @dev Creates a reward.
     * @param _withdrawAmount Initial size for the reward.
     * @param _withdrawDuration Initial duration for the reward.
     */
    function addReward(uint256 _withdrawAmount, uint256 _withdrawDuration) public onlyOwner {
        Reward memory reward;

        reward.id = rewards.length;
        reward.state = RewardState.Disabled;
        reward.poll = _createRewardPoll(rewards.length, _withdrawAmount, _withdrawDuration);
        reward.updated = now;

        rewards.push(reward);
    }

    /**
     * @dev Updates a reward poll
     * @param _id References reward
     * @param _withdrawAmount New size for the reward.
     * @param _withdrawDuration New duration of the reward
     */
    function updateReward(
        uint256 _id,
        uint256 _withdrawAmount,
        uint256 _withdrawDuration
    ) public onlyMember {
        require(rewards[_id].poll.finalized(), 'IS_NOT_FINALIZED');
        require(_withdrawAmount != rewards[_id].withdrawAmount, 'IS_EQUAL');

        rewards[_id].poll = _createRewardPoll(_id, _withdrawAmount, _withdrawDuration);
    }

    /**
     * @dev Creates a withdraw poll for a reward.
     * @param _id Reference id of the reward
     * @param _member The address of the member
     * @param _nonce Number only used once
     * @param _sig The signed parameters
     */
    function claimWithdraw(
        uint256 _id,
        address _member,
        uint256 _nonce,
        bytes calldata _sig
    )
        public
        // _member could be deleted from arguments, as it recoverd
        onlyOwner
        onlyIfMember(_member)
        useNonce(_member, _nonce)
    {
        bytes32 message = Signature.prefixed(keccak256(abi.encodePacked(owner(), _id, _nonce, this)));
        require(Signature.recoverSigner(message, _sig) == _member, 'WRONG_SIG');
        require(rewards[_id].state == RewardState.Enabled, 'IS_NOT_ENABLED');

        WithdrawPoll withdraw = _createWithdrawPoll(
            rewards[_id].withdrawAmount,
            rewards[_id].withdrawDuration,
            _member
        );

        withdraws.push(withdraw);
    }

    /**
     * @dev Creates a custom withdraw proposal.
     * @param _amount Size of the withdrawal
     * @param _beneficiary Address of the beneficiary
     */
    function proposeWithdraw(uint256 _amount, address _beneficiary) public onlyIfMember(_beneficiary) {
        WithdrawPoll withdraw = _createWithdrawPoll(_amount, proposeWithdrawPollDuration, _beneficiary);
        withdraws.push(withdraw);
    }

    /**
     * @dev Starts a withdraw poll.
     * @param _amount Size of the withdrawal
     * @param _duration The duration the withdraw poll
     * @param _beneficiary Beneficiary of the reward
     */
    function _createWithdrawPoll(
        uint256 _amount,
        uint256 _duration,
        address _beneficiary
    ) internal returns (WithdrawPoll) {
        WithdrawPoll poll = new WithdrawPoll(
            _beneficiary,
            _amount,
            now + _duration,
            address(this),
            owner(),
            address(token)
        );

        emit WithdrawPollCreated(_beneficiary, address(poll));
        polls[address(poll)] = true;
        return poll;
    }

    /**
     * @dev Starts a reward poll and stores the address of the poll.
     * @param _id Referenced reward
     * @param _withdrawAmount Size of the reward
     * @param _withdrawDuration Duration of the reward poll
     */
    function _createRewardPoll(
        uint256 _id,
        uint256 _withdrawAmount,
        uint256 _withdrawDuration
    ) internal returns (RewardPoll) {
        RewardPoll poll = new RewardPoll(
            _id,
            _withdrawAmount,
            _withdrawDuration,
            now + rewardPollDuration,
            address(this),
            owner()
        );
        polls[address(poll)] = true;
        return poll;
    }

    /**
     * @dev Called when poll is finished
     * @param _id id of reward
     * @param _withdrawAmount New amount for the reward
     * @param _withdrawDuration New duration for the reward
     * @param _agree Bool for checking the result of the poll
     */
    function onRewardPollFinish(
        uint256 _id,
        uint256 _withdrawAmount,
        uint256 _withdrawDuration,
        bool _agree
    ) external {
        require(address(rewards[_id].poll) == msg.sender);

        if (_agree) {
            rewards[_id].withdrawAmount = _withdrawAmount;
            rewards[_id].withdrawDuration = _withdrawDuration;

            if (_withdrawAmount > 0) {
                rewards[_id].state = RewardState.Enabled;
            } else {
                rewards[_id].state = RewardState.Disabled;
            }
        }
    }

    /**
     * @dev callback called after a withdraw
     * @param _withdraw Address of the withdrawal
     * @param _beneficiary Receiver of the reward
     * @param _amount Size of the reward
     */
    function onWithdrawal(
        address _withdraw,
        address _beneficiary,
        uint256 _amount
    ) external {
        require(_withdraw == msg.sender);

        token.transfer(_beneficiary, _amount);

        emit Withdrawn(_beneficiary, _amount);
    }
}
