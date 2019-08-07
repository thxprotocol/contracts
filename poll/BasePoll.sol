pragma solidity ^0.5.0;

import '../math/SafeMath.sol';
import '../token/ERC20/IERC20.sol';

contract BasePoll {
    using SafeMath for uint256;

    struct Vote {
        uint256 time;
        uint256 weight;
        bool agree;
    }

    uint256 public constant MAX_TOKENS_WEIGHT_DENOM = 1000;

    IERC20 public token;

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
        uint256 _startTime,
        uint256 _endTime,
        bool _checkTransfersAfterEnd
    ) public {
        require(_tokenAddress != address(0));
        require(_startTime >= now && _endTime > _startTime);

        token = IERC20(_tokenAddress);
        startTime = _startTime;
        endTime = _endTime;
        finalized = false;
        checkTransfersAfterEnd = _checkTransfersAfterEnd;
    }

    /**
     * @dev Process user`s vote
     * @param agree True if user endorses the proposal else False
     */
    function vote(bool agree) external checkTime {
        require(votesByAddress[msg.sender].time == 0);

        uint256 voiceWeight = token.balanceOf(msg.sender);
        uint256 maxVoiceWeight = token.totalSupply().div(MAX_TOKENS_WEIGHT_DENOM);
        voiceWeight =  voiceWeight <= maxVoiceWeight ? voiceWeight : maxVoiceWeight;

        if(agree) {
            yesCounter = yesCounter.add(voiceWeight);
        } else {
            noCounter = noCounter.add(voiceWeight);
        }

        votesByAddress[msg.sender].time = now;
        votesByAddress[msg.sender].weight = voiceWeight;
        votesByAddress[msg.sender].agree = agree;

        totalVoted = totalVoted.add(1);
    }

    /**
     * @dev Revoke user`s vote
     */
    function revokeVote() external checkTime {
        require(votesByAddress[msg.sender].time > 0);

        uint256 voiceWeight = votesByAddress[msg.sender].weight;
        bool agree = votesByAddress[msg.sender].agree;

        votesByAddress[msg.sender].time = 0;
        votesByAddress[msg.sender].weight = 0;
        votesByAddress[msg.sender].agree = false;

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

    function isSubjectApproved() internal view returns(bool) {
        return yesCounter > noCounter;
    }

    /**
     * @dev callback called after poll finalization
     */
    function onPollFinish(bool agree) internal;
}
