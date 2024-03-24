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

### 2. Revealing Choices

- after T1 seconds, run revealLottery with the choice and salt as parameter to reveal the choice
- if some player not reveal the choice within T2 seconds, the player will forfeit the ETH
- after T2 seconds, the game will proceed to stage 3

### 3. Determining the Winner

- after T2 seconds, contract owner can run awardLottery to determine the winner and award the prize
- winner calculation is based on hashed XOR of the revealed choices and modulo of the total good lotteries
- winner will receive 98% of the total ETH and contract owner will receive 2% of the total ETH and the game will reset
- if no winner can be determined, the contract owner will receive all forfeited ETH and the game will reset
- if the contract owner isn't determined the winner in T3 seconds, the game will proceed to stage 4

### 4. Withdrawing Funds

- after T3 seconds, players can withdraw their ETH by calling withdraw function
- if all players withdraw their ETH, the game will reset and ready for the next round
