// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

/**

--- Rock Paper Scissors ---

1. It must keep track of an unbounded number of rock-paper-scissors games;
2. Each game should be identifiable by a unique ID;
3. Once two players commit their move to the same game ID, the game is now resolved, and no further moves can be played;
4. Each game, once started, needs both moves to be played within 48h. If that doesn’t happen, the first player can get a full refund;
5. To play, both users have to commit a predetermined amount of ETH (to be decided by the contract deployer);
6. It should be impossible for the second player to figure out what the first player’s move was before both moves are committed;
7. When a game is finished, the winner gets to take the full pot;
8. In the event of a draw, each player can recover only 50% of their locked amount. The other 50% are to be distributed to the next game that finishes;
9. The repo should include some unit tests to simulate and test the main behaviors of the game. Extra love will be given if you showcase security skills (fuzzing, mutation testing, etcetera).

 */

error FeeIsIncorrect();
error GameIsNotLive();
error GameIsNotStarted();
error GameIsExpired();
error OnlyCreatorCanRevealTheirMove();
error MoveDoesNotMatchCommit();
error GameHasBothPlayers();
error GameIsAlreadyFinalized();
error GameIsNotExpired();
error NoOpponent();
error NotAValidMove();
error GameCreatorMoveIsNotRevealed();

enum Move {
    NONE,
    ROCK,
    PAPER,
    SCISSOR
}

enum GameStatus {
    NOTSTARTED,
    LIVE,
    ENDED
}

struct Game {
    GameStatus status;
    address creator;
    Move creatorMove;
    Move opponentMove;
    address opponent;
    bytes32 creatorCommitHash;
    uint256 startTime;
}

contract RockPaperScissors {
    uint256 public immutable fee;
    uint256 public constant MAX_GAME_DURATION = 48 hours;
    uint256 public poolAmount;
    uint256 public numGames;
    mapping(uint256 => Game) public games;
    bool private _txLock;

    event GameExpired(uint256 indexed gameId);
    event Won(uint256 indexed gameId, address indexed winner);
    event Tied(
        uint256 indexed gameId,
        address indexed player,
        address indexed opponent
    );

    /// @notice Contract Constructor sets the fee for participating in each game.
    /// @param _fee amount to participate in a game
    constructor(uint256 _fee) {
        fee = _fee;
    }

    /// @notice sends `amount` ETH to `to`
    /// @param to address of the receiver
    /// @param amount ETH amount to send
    function _sendETH(address to, uint256 amount) internal {
        if (!_txLock) {
            _txLock = true;
            // we don't check the success value here, but we could based on the success
            // value, if failed to try to send wETH to the address
            to.call{value: amount}("");
        }

        _txLock = false;
    }

    /// @notice The function to start the game called by the 1st player.
    /// @param commitHash hash to be used for the 1st player's move commitment scheme.
    function startGame(bytes32 commitHash) external payable {
        if (msg.value != fee) {
            revert FeeIsIncorrect();
        }

        Game storage game = games[numGames];
        game.status = GameStatus.LIVE;
        game.creator = msg.sender;
        game.creatorCommitHash = commitHash;
        game.startTime = block.timestamp;

        unchecked {
            ++numGames;
        }
    }

    /// @notice This function is used by a 2nd player to join a game that is already
    /// started and needs an opponent
    /// @param gameId id of the game for `games` state variable
    /// @param move 2nd player's move. The move must be either ROCK, PAPER or SCISSOR
    function joinGame(uint256 gameId, Move move) external payable {
        if (msg.value != fee) {
            revert FeeIsIncorrect();
        } else if (move == Move.NONE || uint(move) > uint(Move.SCISSOR)) {
            revert NotAValidMove();
        }

        Game storage game = games[gameId];

        if (game.status != GameStatus.LIVE) {
            revert GameIsNotLive();
        } else if (isGameExpired(gameId)) {
            revert GameIsExpired();
        } else if (game.opponent != address(0)) {
            revert GameHasBothPlayers();
        }

        game.opponent = msg.sender;
        game.opponentMove = move;
    }

    /// @notice After the 2nd player makes a move in `games[gameId]`, the 1st player
    /// would need to reveal their `move` using a predefined commitment schem and
    /// the `_commitHash` they had already submitted to the `startGame` function
    /// @param gameId id of the game for `games` state variable
    /// @param move 1st player's move
    /// @param nonce used for 1st player's commitment scheme
    function revealMove(
        uint256 gameId,
        Move move,
        uint256 nonce
    ) external {
        if (move == Move.NONE || uint(move) > uint(Move.SCISSOR)) {
            revert NotAValidMove();
        }

        Game storage game = games[gameId];

        if (game.status != GameStatus.LIVE) {
            revert GameIsNotLive();
        } else if (game.opponent == address(0)) {
            revert NoOpponent();
        } else if (game.creator != msg.sender) {
            revert OnlyCreatorCanRevealTheirMove();
        }

        if (
            keccak256(abi.encodePacked(msg.sender, move, nonce)) ==
            game.creatorCommitHash
        ) {
            game.creatorMove = move;
        } else {
            revert MoveDoesNotMatchCommit();
        }
    }

    /// @notice Finalizes the `games[gameId]` and determines the winner
    /// @param gameId id of the game for `games` state variable
    function finalize(uint256 gameId) external {
        Game storage game = games[gameId];

        if (game.status == GameStatus.NOTSTARTED) {
            revert GameIsNotStarted();
        } else if (game.status == GameStatus.ENDED) {
            revert GameIsAlreadyFinalized();
        }

        if (game.opponent != address(0)) {
            if(game.creatorMove == Move.NONE) {
                revert GameCreatorMoveIsNotRevealed();
            }
            game.status = GameStatus.ENDED;
            uint256 diff = (3 +
                uint256(game.creatorMove) -
                uint256(game.opponentMove)) % 3;
            if (diff == 0) {
                uint256 halfFee = fee / 2;

                poolAmount += fee + (fee % 2) * 2;
                emit Tied(gameId, game.creator, game.opponent);

                _sendETH(game.creator, halfFee);
                _sendETH(game.opponent, halfFee);
            } else if (diff == 2) {
                emit Won(gameId, game.opponent);
                uint256 amount = 2 * fee + poolAmount;
                poolAmount = 0;
                _sendETH(game.opponent, amount);
            } else {
                emit Won(gameId, game.creator);
                uint256 amount = 2 * fee + poolAmount;
                poolAmount = 0;
                _sendETH(game.creator, amount);
            }
        } else if (isGameExpired(gameId)) {
            game.status = GameStatus.ENDED;
            emit GameExpired(gameId);
            _sendETH(game.creator, fee);
        } else {
            revert GameIsNotExpired();
        }
    }

    /// @notice check to see if `games[gameId]` has been expired
    /// @param gameId id of the game for `games` state variable
    function isGameExpired(uint256 gameId) public view returns (bool) {
        if (games[gameId].status == GameStatus.NOTSTARTED) {
            revert GameIsNotStarted();
        }

        return (games[gameId].startTime + MAX_GAME_DURATION) <= block.timestamp;
    }
}
