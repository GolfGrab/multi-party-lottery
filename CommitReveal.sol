// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract CommitReveal {
    struct Commit {
        bytes32 commit;
        uint64 block;
        bool revealed;
    }

    mapping(uint256 => Commit) internal commits;

    function commit(uint256 lotteryId, bytes32 dataHash) internal {
        commits[lotteryId].commit = dataHash;
        commits[lotteryId].block = uint64(block.number);
        commits[lotteryId].revealed = false;
        emit CommitHash(
            msg.sender,
            lotteryId,
            commits[lotteryId].commit,
            commits[lotteryId].block
        );
    }
    event CommitHash(
        address sender,
        uint256 lotteryId,
        bytes32 dataHash,
        uint64 block
    );

    function revealChoice(
        uint256 lotteryId,
        uint16 choice,
        bytes32 salt
    ) internal {
        //make sure it hasn't been revealed yet and set it to revealed
        require(
            commits[lotteryId].revealed == false,
            "CommitReveal::revealChoice: Already revealed"
        );
        commits[lotteryId].revealed = true;
        //require that they can produce the committed hash
        require(
            getSaltedHash(choice, salt) == commits[lotteryId].commit,
            "CommitReveal::revealChoice: Revealed hash does not match commit"
        );
        emit RevealChoice(msg.sender, choice, salt);
    }
    event RevealChoice(address sender, uint16 choice, bytes32 salt);

    function getSaltedHash(
        uint16 choice,
        bytes32 salt
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), choice, salt));
    }
}
