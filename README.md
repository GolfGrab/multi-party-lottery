# Multi-Party Lottery

This is a Solidity smart contract for a betting random lottery base on hashed xor of the player inputs.

## Try it out

you can try it out on the [sepolia testnet](https://sepolia.etherscan.io/address/0x5137686d2928526621bcd4d33881b4551caea906#code)
or clone the repo and run contract on your local machine using remix ide or other tools.

## Rules

### Stage 1: Committing Choices (T1 seconds)

- N users can join the lottery.
- Users commit their choices by sending a transaction with a value of 0.001 ETH.
- Commitments are hashed and kept secret.
- After T1 seconds, the game moves to Stage 2.

### Stage 2: Revealing Choices (T2 seconds)

- Users reveal their choices by sending a transaction with their choice and salt.
- Users who do not reveal their choices within T2 seconds forfeit their ETH.
- After T2 seconds, the game moves to Stage 3.

### Stage 3: Determining the Winner (T3 seconds)

- The contract owner determines the winner using XOR and modulo.
- Users who choose values outside the range 0-999 are disqualified and forfeit their ETH.
- The winner receives 0.001 ETH _num_participants_ 0.98.
- The contract owner receives 0.001 ETH _num_participants_ 0.02.
- If no winner can be determined, the contract owner receives all forfeited ETH.
- After T3 seconds, the game moves to Stage 4.

### Stage 4: Withdrawing Funds

- Users can withdraw their ETH if contract owner isn't determined the winner.

### Additional Notes

- The values of N, T1, T2, and T3 can be set in the lottery constructor.

## How to use

### 1. Committing Choices

- run getSaltedHash function to get the hash of the address, choice and salt
- call commitHashedLottery with the hash as parameter and send 0.001 ETH
- if first player commit the hash, the game will start counting T1 seconds
- after T1 seconds, the game will proceed to stage 2

```solidity
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
```

### 2. Revealing Choices

- after T1 seconds, run revealLottery with the choice and salt as parameter to reveal the choice
- if some player not reveal the choice within T2 seconds, the player will forfeit the ETH
- after T2 seconds, the game will proceed to stage 3

````solidity
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
    ```

### 3. Determining the Winner

- after T2 seconds, contract owner can run awardLottery to determine the winner and award the prize
- winner calculation is based on hashed XOR of the revealed choices and modulo of the total good lotteries
- winner will receive 98% of the total ETH and contract owner will receive 2% of the total ETH and the game will reset
- if no winner can be determined, the contract owner will receive all forfeited ETH and the game will reset
- if the contract owner isn't determined the winner in T3 seconds, the game will proceed to stage 4

```solidity
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
    ```

### 4. Withdrawing Funds

- after T3 seconds, players can withdraw their ETH by calling withdraw function
- if all players withdraw their ETH, the game will reset and ready for the next round

```solidity
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
    ```
````
