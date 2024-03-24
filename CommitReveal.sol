// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract CommitReveal {

  struct Commit {
    bytes32 commit;
    uint64 block;
    bool revealed;
  }

  mapping (address => Commit) internal commits;

  function commit(bytes32 dataHash) internal {
    commits[msg.sender].commit = dataHash;
    commits[msg.sender].block = uint64(block.number);
    commits[msg.sender].revealed = false;
    emit CommitHash(msg.sender,commits[msg.sender].commit,commits[msg.sender].block);
  }
  event CommitHash(address sender, bytes32 dataHash, uint64 block);

  function revealAnswer(bytes32 answer,bytes32 salt) internal {
    //make sure it hasn't been revealed yet and set it to revealed
    require(commits[msg.sender].revealed==false,"CommitReveal::revealAnswer: Already revealed");
    commits[msg.sender].revealed=true;
    //require that they can produce the committed hash
    require(getSaltedHash(answer,salt)==commits[msg.sender].commit,"CommitReveal::revealAnswer: Revealed hash does not match commit");
    emit RevealAnswer(msg.sender,answer,salt);
  }
  event RevealAnswer(address sender, bytes32 answer, bytes32 salt);

  function getSaltedHash(bytes32 data,bytes32 salt) public view returns(bytes32){
    return keccak256(abi.encodePacked(address(this), data, salt));
  }

}
