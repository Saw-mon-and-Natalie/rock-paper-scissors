// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

contract MockBadActor {
    uint8 private numReenters;
    uint256 gameId;

    constructor(uint8 _numReenters) {
        numReenters = _numReenters;
    }

    function setGameId(uint256 _gameId) external {
        gameId = _gameId;
    }
    fallback() external payable {
        uint8 count = 0;
        
        if(msg.value > 0 && count < numReenters) {
            (bool success, ) = msg.sender.call(abi.encodeWithSignature("finalize(uint256)", gameId));
            if(!success) {
                count = numReenters;
            }
            ++count;
        }
    }
}