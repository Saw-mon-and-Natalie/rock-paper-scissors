# Rock Paper Scissors

![Tests Badge](https://github.com/Saw-mon-and-Natalie/rock-paper-scissors/actions/workflows/tests.yml/badge.svg)
![Slither Badge](https://github.com/Saw-mon-and-Natalie/rock-paper-scissors/actions/workflows/slither.yml/badge.svg)

The game starts by the 1st player sharing a commit hash and sending the required fee. From this point on, a 2nd player can join the the same game using the unique `gameId` associated to this game. The 2nd player would need to send their move (rock, paper or scissor) along with the required fee to play the game. After a 2nd player joins the game, the 1st player would need to reveal their move by sharing their `move` along with the `nonce` they used to created their commitment hash which was shared earlier during the game creation. Finally, anyone (either the players or a 3rd party) can call the `finalize` function on the contract using the same `gameId` to end the game if all the required criteria are met and distribute the prizes among the winners.

This repository uses [`foundry/forge`](https://github.com/foundry-rs/foundry) to compile and test the contracts.

To install dependencies run:

```bash
forge install
```

To test run:

```bash
forge test
```


## Vulnerabilities

If a game ends in a tie, a malicous actor can play a game against themselves to win the accured `poolAmount`. Even if we add a check to make sure the two players have different addresses, the bad actor can easily use 2 different wallets.

For additional vulnerability analysis, we also use [Slither](https://github.com/crytic/slither):
```bash
slither src/RockPaperScissors.sol
```

[Slither](https://github.com/crytic/slither) returns vulnerabilities against the internal `_sendETH` function which is guarded against reenterency using a locking mechanism at 2 different locations.

## TODO

- [ ] Clean up the test file
- [ ] Optimize the main contract