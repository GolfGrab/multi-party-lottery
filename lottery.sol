// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;
import "./CommitReveal.sol";
import "./Ownable.sol";

contract MultiPartyLottery is Ownable, CommitReveal {
    uint16 public gameStage = 0; // 0: idle, 1: commit, 2: reveal, 3: award , 4: award timeout
    uint256 public startStageTime = block.timestamp;
    uint256 public _T1; //commit stage duration
    uint256 public _T2; //reveal stage duration
    uint256 public _T3; //award  stage duration
    uint256 public _N; // maximum number of lottery participants
    uint256 public num_participants = 0;
    uint16 constant MinimumChoice = 0;
    uint16 constant MaximumChoice = 999;

    struct Lottery {
        uint16 choice; // 0 - 999
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
        _N = _maximumPlayerLimit;
        _T1 = _commitLotteryStageDuration;
        _T2 = _revealStageDuration;
        _T3 = _awardStageDuration;
    }

    function startGame() public onlyOwner {
        require(
            gameStage == 0,
            "MultiPartyLottery::startGame: Game is not idle"
        );
        gameStage = 1;
        startStageTime = block.timestamp;
    }

    function commitHashedLottery(bytes32 _hashedLottery) public payable {
        require(msg.value == 0.001 ether, "require 0.001 ether to participate");
        require(
            gameStage == 1,
            "MultiPartyLottery::commitHashLottery: Game is not in commit stage"
        );
        require(
            num_participants < _N,
            "MultiPartyLottery::commitHashLottery: Maximum number of players limit exceeded"
        );
        require(
            block.timestamp < startStageTime + _T1,
            "MultiPartyLottery::commitHashLottery: Timeout"
        );

        uint256 lotteryId = num_participants;

        lotteries[lotteryId] = Lottery({
            choice: 0,
            isRevealed: false,
            isWithdrawn: false,
            addr: msg.sender
        });

        commit(lotteryId, _hashedLottery);

        num_participants++;
    }

    function changeGameStageToReveal() public {
        require(
            gameStage == 1,
            "MultiPartyLottery::changeGameStageToReveal: Game is not in commit stage"
        );
        require(
            block.timestamp > startStageTime + _T1,
            "MultiPartyLottery::changeGameStageToReveal: Commit stage is not over"
        );
        gameStage = 2;
        startStageTime = block.timestamp;
    }

    function revealLottery(
        uint256 _lotteryId,
        uint16 _choice,
        bytes32 _salt
    ) public {
        require(
            gameStage == 2,
            "MultiPartyLottery::revealLottery: Game is not in reveal stage"
        );
        require(
            block.timestamp < startStageTime + _T2,
            "MultiPartyLottery::revealLottery: Timeout"
        );

        revealChoice(_lotteryId, _choice, _salt);

        lotteries[_lotteryId].choice = _choice;
        lotteries[_lotteryId].isRevealed;
    }

    function changeGameStageToAward() public onlyOwner {
        require(
            gameStage == 2,
            "MultiPartyLottery::changeGameStageToAward: Game is not in reveal stage"
        );
        require(
            block.timestamp > startStageTime + _T2,
            "MultiPartyLottery::changeGameStageToAward: Reveal stage is not over"
        );
        gameStage = 3;
        startStageTime = block.timestamp;
    }

    function awardLottery() public onlyOwner {
        require(
            gameStage == 3,
            "MultiPartyLottery::awardLottery: Game is not in award stage"
        );
        require(
            block.timestamp < startStageTime + _T3,
            "MultiPartyLottery::awardLottery: Timeout"
        );

        Lottery[] memory goodLotteries = new Lottery[](num_participants);
        uint256 goodLotteriesCount = 0;

        for (uint256 i = 0; i < _N; i++) {
            if (
                lotteries[i].isRevealed &&
                lotteries[i].choice >= MinimumChoice &&
                lotteries[i].choice <= MaximumChoice
            ) {
                goodLotteries[goodLotteriesCount] = lotteries[i];
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

        gameStage = 0;
        num_participants = 0;
        startStageTime = block.timestamp;
    }

    function _ownerGetAllReward() private {
        payable(owner()).transfer(0.001 ether * num_participants);
    }

    function _rewardWinner(address _winner) private {
        // winner get 0.001 ETH * num_participants * 0.98
        // owner get 0.001 ETH * num_participants * 0.02
        uint256 winnerReward = (0.001 ether * num_participants * 98) / 100;
        uint256 ownerReward = (0.001 ether * num_participants * 2) / 100;

        payable(_winner).transfer(winnerReward);
        payable(owner()).transfer(ownerReward);
    }

    function changeGameStageToAwardTimeout() public {
        require(
            gameStage == 3,
            "MultiPartyLottery::changeGameStageToAwardTimeout: Game is not in award stage"
        );
        require(
            block.timestamp > startStageTime + _T3,
            "MultiPartyLottery::changeGameStageToAwardTimeout: Award stage is not over"
        );
        gameStage = 4;
        startStageTime = block.timestamp;
    }

    function withdraw(uint256 lotteryId) public {
        require(
            gameStage == 4,
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
        payable(msg.sender).transfer(0.001 ether);
    }
}
