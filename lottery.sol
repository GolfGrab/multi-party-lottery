// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;
import "./CommitReveal.sol";
import "./Ownable.sol";

contract MultiPartyLottery is Ownable, CommitReveal {
    uint16 private _gameStage = 0; // 0: idle, 1: playing  [commit, reveal, award,  award timeout]
    uint256 public startStageTime = block.timestamp;
    uint256 public T1; //commit stage duration
    uint256 public T2; //reveal stage duration
    uint256 public T3; //award  stage duration
    uint256 public N; // maximum number of lottery participants
    uint256 private _num_participants = 0;
    uint256 private _num_revealed = 0;
    uint16 constant MinimumChoice = 0;
    uint16 constant MaximumChoice = 999;
    uint256 constant LotteryFee = 0.001 ether;

    struct Lottery {
        uint16 choice; // 0 - 999
        bool isCommitted;
        bool isRevealed;
        bool isWithdrawn;
        address addr;
    }

    mapping(uint256 => Lottery) public lotteries;

    constructor(
        uint256 _maximumPlayerLimit,
        uint256 _commitLotteryStageDuration,
        uint256 _revealStageDuration,
        uint256 _awardStageDuration
    ) {
        N = _maximumPlayerLimit;
        T1 = _commitLotteryStageDuration;
        T2 = _revealStageDuration;
        T3 = _awardStageDuration;
    }

    function getGameStage()
        public
        view
        returns (string memory, uint, string memory)
    {
        if (_gameStage == 0) {
            return ("Idle", 0, "");
        }

        if (_gameStage == 1) {
            if (block.timestamp <= startStageTime + T1) {
                return (
                    "Commit Stage : end in ",
                    startStageTime + T1 - block.timestamp,
                    " seconds"
                );
            } else if (block.timestamp <= startStageTime + T1 + T2) {
                return (
                    "Reveal Stage : end in ",
                    startStageTime + T1 + T2 - block.timestamp,
                    " seconds"
                );
            } else if (block.timestamp <= startStageTime + T1 + T2 + T3) {
                return (
                    "Award Stage : end in ",
                    startStageTime + T1 + T2 + T3 - block.timestamp,
                    " seconds"
                );
            } else if (block.timestamp > startStageTime + T1 + T2 + T3) {
                return ("Award Timeout", 0, "");
            }
        }

        return ("", 0, "");
    }

    function commitHashedLottery(
        bytes32 _hashedLottery
    ) public payable returns (uint256) {
        require(
            msg.value == LotteryFee,
            "require LotteryFee (0.001 ether) to participate"
        );
        require(
            _num_participants < N,
            "MultiPartyLottery::commitHashLottery: Maximum number of players limit exceeded"
        );

        // start the game when the first player joins
        if (_gameStage == 0) {
            _gameStage = 1;
            startStageTime = block.timestamp;
        }

        require(
            block.timestamp <= startStageTime + T1,
            "MultiPartyLottery::commitHashLottery: Game is not in commit stage"
        );

        uint256 lotteryId = _num_participants;

        lotteries[lotteryId] = Lottery({
            choice: 0,
            isCommitted: true,
            isRevealed: false,
            isWithdrawn: false,
            addr: msg.sender
        });

        commit(lotteryId, _hashedLottery);

        _num_participants++;

        return lotteryId;
    }

    function revealLottery(
        uint256 _lotteryId,
        uint16 _choice,
        string memory _salt
    ) public {
        require(
            startStageTime + T1 < block.timestamp &&
                block.timestamp < startStageTime + T1 + T2,
            "MultiPartyLottery::revealLottery: Game is not in reveal stage"
        );
        require(
            lotteries[_lotteryId].addr == msg.sender,
            "MultiPartyLottery::revealLottery: You are not the owner of this lottery"
        );

        revealChoice(_lotteryId, _choice, _salt);

        lotteries[_lotteryId].choice = _choice;
        lotteries[_lotteryId].isRevealed = true;
        _num_revealed++;
    }

    function awardLottery() public onlyOwner {
        require(
            startStageTime + T1 + T2 < block.timestamp &&
                block.timestamp < startStageTime + T1 + T2 + T3,
            "MultiPartyLottery::awardLottery: Game is not in award stage"
        );

        Lottery[] memory goodLotteries = new Lottery[](_num_participants);
        uint256 goodLotteriesCount = 0;

        for (uint256 i = 0; i < N; i++) {
            if (
                lotteries[i].isRevealed &&
                lotteries[i].choice >= MinimumChoice &&
                lotteries[i].choice <= MaximumChoice
            ) {
                goodLotteries[goodLotteriesCount].choice = lotteries[i].choice;
                goodLotteries[goodLotteriesCount].addr = lotteries[i].addr;
                goodLotteries[goodLotteriesCount].isCommitted = lotteries[i]
                    .isCommitted;
                goodLotteries[goodLotteriesCount].isRevealed = lotteries[i]
                    .isRevealed;
                goodLotteries[goodLotteriesCount].isWithdrawn = lotteries[i]
                    .isWithdrawn;

                goodLotteriesCount++;
            }
        }

        if (goodLotteriesCount == 0) {
            _ownerGetAllReward();
        }

        // find the winner index by calculating hash of all XORed choices
        uint256 xorChoices = goodLotteries[0].choice;
        for (uint256 i = 1; i < goodLotteriesCount; i++) {
            xorChoices = xorChoices ^ goodLotteries[i].choice;
        }
        uint256 winnerIndex = uint256(keccak256(abi.encodePacked(xorChoices))) %
            goodLotteriesCount;

        _rewardWinner(goodLotteries[winnerIndex].addr);
        _resetGame();
    }

    function _ownerGetAllReward() private {
        payable(owner()).transfer(LotteryFee * _num_participants);
    }

    function _rewardWinner(address _winner) private {
        // winner get 0.001 ETH * _num_participants * 0.98
        // owner get 0.001 ETH * _num_participants * 0.02
        uint256 winnerReward = (LotteryFee * _num_participants * 98) / 100;
        uint256 ownerReward = (LotteryFee * _num_participants * 2) / 100;

        payable(_winner).transfer(winnerReward);
        payable(owner()).transfer(ownerReward);
    }

    function withdraw(uint256 lotteryId) public {
        require(
            startStageTime + T1 + T2 + T3 < block.timestamp,
            "MultiPartyLottery::withdraw: Game is not in award timeout stage"
        );
        require(
            lotteries[lotteryId].addr == msg.sender,
            "MultiPartyLottery::withdraw: You are not the owner of this lottery"
        );
        require(
            lotteries[lotteryId].isWithdrawn == false,
            "MultiPartyLottery::withdraw: You have already withdrawn this lottery"
        );
        lotteries[lotteryId].isWithdrawn = true;
        payable(msg.sender).transfer(LotteryFee);

        _num_participants--;

        if (_num_participants == 0) {
            _resetGame();
        }
    }

    function _resetGame() private {
        _gameStage = 0;
        _num_participants = 0;
        _num_revealed = 0;
        startStageTime = block.timestamp;
    }
}
