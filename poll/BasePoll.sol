pragma solidity ^0.6.4;

import '../math/SafeMath.sol';
import '../token/ERC20/IERC20.sol';
import '../IRewardPool.sol';

contract BasePoll {
    using SafeMath for uint256;

    struct Vote {
        uint256 time;
        uint256 weight;
        bool agree;
    }

    uint256 public constant MAX_TOKENS_WEIGHT_DENOM = 1000;

    IERC20 public token;
    IRewardPool public pool;

    uint256 public startTime;
    uint256 public endTime;
    bool checkTransfersAfterEnd;

    uint256 public yesCounter = 0;
    uint256 public noCounter = 0;
    uint256 public totalVoted = 0;

    bool public finalized;
    mapping(address => Vote) public votesByAddress;

    modifier checkTime() {
        require(now >= startTime && now <= endTime);
        _;
    }

    modifier notFinalized() {
        require(!finalized);
        _;
    }

    /**
     * @dev BasePoll constructor
     * @param _tokenAddress ERC20 compatible token contract address
     * @param _startTime Poll start time
     * @param _endTime Poll end time
     * @param _checkTransfersAfterEnd Checks transfer after end
     */
    constructor(
        address _tokenAddress,
        address _poolAddress,
        uint256 _startTime,
        uint256 _endTime,
        bool _checkTransfersAfterEnd
    ) public {
        require(_tokenAddress != address(0));
        require(_startTime >= now && _endTime > _startTime);

        token = IERC20(_tokenAddress);
        pool = IRewardPool(_poolAddress);

        startTime = _startTime;
        endTime = _endTime;
        finalized = false;
        checkTransfersAfterEnd = _checkTransfersAfterEnd;
    }

    /**
     * @dev Process user`s vote
     * @param voter The address of the user voting
     * @param agree True if user endorses the proposal else False
     */
    function vote(address voter, bool agree) external checkTime {
        require(voter != address(0));
        require(votesByAddress[voter].time == 0);

        uint256 voiceWeight = token.balanceOf(voter);
        uint256 maxVoiceWeight = token.totalSupply().div(MAX_TOKENS_WEIGHT_DENOM);
        voiceWeight = voiceWeight <= maxVoiceWeight ? voiceWeight : maxVoiceWeight;

        if(agree) {
            yesCounter = yesCounter.add(voiceWeight);
        } else {
            noCounter = noCounter.add(voiceWeight);
        }

        votesByAddress[voter].time = now;
        votesByAddress[voter].weight = voiceWeight;
        votesByAddress[voter].agree = agree;

        totalVoted = totalVoted.add(1);
    }

    /**
     * @dev Revoke user`s vote
     * @param voter The address of the user voting
     */
    function revokeVote(address voter) external checkTime {
        require(votesByAddress[voter].time > 0);

        uint256 voiceWeight = votesByAddress[voter].weight;
        bool agree = votesByAddress[voter].agree;

        votesByAddress[voter].time = 0;
        votesByAddress[voter].weight = 0;
        votesByAddress[voter].agree = false;

        totalVoted = totalVoted.sub(1);
        if(agree) {
            yesCounter = yesCounter.sub(voiceWeight);
        } else {
            noCounter = noCounter.sub(voiceWeight);
        }
    }

    /**
     * @dev Function is called after token transfer from user`s wallet to check and correct user`s vote
     *
     */
    /* function onTokenTransfer(address tokenHolder, uint256 amount) public {
        require(msg.sender == fundAddress);
        if(votesByAddress[tokenHolder].time == 0) {
            return;
        }
        if(!checkTransfersAfterEnd) {
             if(finalized || (now < startTime || now > endTime)) {
                 return;
             }
        }

        if(token.balanceOf(tokenHolder) >= votesByAddress[tokenHolder].weight) {
            return;
        }
        uint256 voiceWeight = amount;
        if(amount > votesByAddress[tokenHolder].weight) {
            voiceWeight = votesByAddress[tokenHolder].weight;
        }

        if(votesByAddress[tokenHolder].agree) {
            yesCounter = yesCounter.sub(voiceWeight);
        } else {
            noCounter = noCounter.sub(voiceWeight);
        }
        votesByAddress[tokenHolder].weight = votesByAddress[tokenHolder].weight.sub(voiceWeight);
    } */

    /**
     * Finalize poll and call onPollFinish callback with result
     */
    function tryToFinalize() public notFinalized returns(bool) {
        if(now < endTime) {
            return false;
        }
        finalized = true;
        onPollFinish(isSubjectApproved());
        return true;
    }

    function isNowApproved() public view returns(bool) {
        return isSubjectApproved();
    }

    function isSubjectApproved() internal view virtual returns(bool) {
        return yesCounter > noCounter;
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool agree) internal virtual {}
}
