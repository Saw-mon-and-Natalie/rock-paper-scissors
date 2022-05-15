// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "forge-std/Test.sol";
import {RockPaperScissors, Move, GameStatus, Game} from "../RockPaperScissors.sol";
import { MockBadActor } from "./utils/MockBadActor.sol";

contract RockPaperScissorsTest is Test {
    RockPaperScissors rps;
    uint256 fee;
    uint256 lowFee;

    address Sawmon;
    address Natalie;
    address Cristiano;
    address Elizabeth;

    MockBadActor badActor;

    event GameExpired(uint256 indexed gameId);
    event Won(uint256 indexed gameId, address indexed winner);
    event Tied(
        uint256 indexed gameId,
        address indexed player,
        address indexed opponent
    );

    function setUp() public {
        fee = 0.061 ether;
        lowFee = 0.001_150_000 ether;
        rps = new RockPaperScissors(fee);

        Sawmon = address(0x5a3);
        Natalie = address(0x2a7);
        Cristiano = address(0xC51);
        Elizabeth = address(0xE11);

        badActor = new MockBadActor(1);

        vm.label(Sawmon, "Saw-mon");
        vm.label(Natalie, "Natalie");
        vm.label(Cristiano, "Cristiano");
        vm.label(Elizabeth, "Elizabeth");
        vm.label(address(badActor), "Bad Actor");

        vm.deal(Sawmon, 12 ether);
        vm.deal(Natalie, 6 ether);
        vm.deal(Cristiano, 2022 ether);
        vm.deal(Elizabeth, 6 ether);
        vm.deal(address(badActor), 2 ether);
    }

    function _setupGame(
        address _creator,
        address _opponent,
        Move _creatorMove,
        Move _opponentMove,
        uint256 _nonce
    )
        internal
        returns (
            uint256,
            uint256,
            bytes32
        )
    {
        bytes32 commitHash = keccak256(
            abi.encodePacked(_creator, _creatorMove, _nonce)
        );
        vm.prank(_creator);
        rps.startGame{value: fee}(commitHash);

        uint256 gameId = rps.numGames() - 1;
        uint256 poolAmountInitial = rps.poolAmount();

        vm.prank(_opponent);
        rps.joinGame{value: fee}(gameId, _opponentMove);

        vm.prank(_creator);
        rps.revealMove(gameId, _creatorMove, _nonce);

        return (
            gameId,
            poolAmountInitial,
            commitHash
        );
    }

    function testGameFee() public {
        assertEq(rps.fee(), fee);
    }

    function testMaxGameDuration() public {
        assertEq(rps.MAX_GAME_DURATION(), 48 hours);
    }

    function testGameIsNotStarted() public {
        (GameStatus status, , , , , , ) = rps.games(0);
        assertTrue(status == GameStatus.NOTSTARTED);
    }

    function testInitialNumGames() public {
        assertEq(rps.numGames(), 0);
    }

    function testInitialPoolAmount() public {
        assertEq(rps.poolAmount(), 0);
    }

    function testStartGameWithInCorrectFee() public {
        vm.expectRevert(abi.encodeWithSignature("FeeIsIncorrect()"));

        bytes32 commitHash = bytes32(uint256(0x11fe));
        vm.prank(Sawmon);
        rps.startGame{value: lowFee}(commitHash);
    }

    function testStartGameWithCorrectFee() public {
        bytes32 commitHash = bytes32(uint256(0xba2a2a));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        assertEq(rps.numGames(), 1);

        (
            GameStatus status,
            address creator,
            Move creatorMove,
            Move opponentMove,
            address opponent,
            bytes32 creatorCommitHash,
            uint256 startTime
        ) = rps.games(0);

        assertTrue(status == GameStatus.LIVE);
        assertEq(creator, Sawmon);
        assertTrue(creatorMove == Move.NONE);
        assertTrue(opponentMove == Move.NONE);
        assertEq(opponent, address(0));
        assertEq(creatorCommitHash, commitHash);
        assertEq(startTime, block.timestamp);
    }

    function testJoinGameWithIncorrectFee() public {
        vm.expectRevert(abi.encodeWithSignature("FeeIsIncorrect()"));

        vm.prank(Cristiano);
        rps.joinGame{value: lowFee}(42, Move.SCISSOR);
    }

    function testJoinGameWithIncorrectMove() public {
        vm.expectRevert(abi.encodeWithSignature("NotAValidMove()"));

        vm.prank(Cristiano);
        rps.joinGame{value: fee}(13, Move.NONE);
    }

    function testJoinGameWithGameStatusNotLive() public {
        vm.expectRevert(abi.encodeWithSignature("GameIsNotLive()"));

        vm.prank(Cristiano);
        rps.joinGame{value: fee}(16, Move.ROCK);
    }

    function testJoinGameWithExpiredGame() public {
        vm.warp(0);

        bytes32 commitHash = bytes32(uint256(0xba29));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        vm.warp(rps.MAX_GAME_DURATION());

        vm.expectRevert(abi.encodeWithSignature("GameIsExpired()"));

        vm.prank(Cristiano);
        rps.joinGame{value: fee}(0, Move.PAPER);
    }

    function testJoinGameWithGameWith2PlayersFilled() public {
        vm.warp(0);

        bytes32 commitHash = bytes32(uint256(0xba29));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        vm.warp(1 hours);

        vm.prank(Cristiano);
        rps.joinGame{value: fee}(0, Move.PAPER);

        vm.expectRevert(abi.encodeWithSignature("GameHasBothPlayers()"));

        vm.warp(2 hours);

        vm.prank(Natalie);
        rps.joinGame{value: fee}(0, Move.ROCK);
    }

    function testJoinGameWithCorrectParameters() public {
        vm.warp(0);

        bytes32 commitHash = bytes32(uint256(0xba29));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        vm.warp(1 hours);

        vm.prank(Cristiano);
        rps.joinGame{value: fee}(0, Move.SCISSOR);

        (
            GameStatus status,
            address creator,
            Move creatorMove,
            Move opponentMove,
            address opponent,
            bytes32 creatorCommitHash,
            uint256 startTime
        ) = rps.games(0);

        assertTrue(status == GameStatus.LIVE);
        assertEq(creator, Sawmon);
        assertTrue(creatorMove == Move.NONE);
        assertTrue(opponentMove == Move.SCISSOR);
        assertEq(opponent, Cristiano);
        assertEq(creatorCommitHash, commitHash);
        assertEq(startTime, 0);
    }

    function testRevealMoveWithNotAValidMove() public {
        vm.expectRevert(abi.encodeWithSignature("NotAValidMove()"));
        rps.revealMove(0, Move.NONE, 0);
    }

    function testRevealMoveWithGameNotStarted() public {
        vm.expectRevert(abi.encodeWithSignature("GameIsNotLive()"));
        rps.revealMove(0, Move.ROCK, 0);
    }

    function testRevealMoveWithNoOpponent() public {
        bytes32 commitHash = bytes32(uint256(0x11fe));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        vm.expectRevert(abi.encodeWithSignature("NoOpponent()"));

        rps.revealMove(0, Move.ROCK, 0);
    }

    function testRevealMoveWithMsgSendNotTheCreator() public {
        bytes32 commitHash = bytes32(uint256(0x11fe));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        vm.warp(1 hours);

        vm.prank(Cristiano);
        rps.joinGame{value: fee}(0, Move.PAPER);

        vm.expectRevert(
            abi.encodeWithSignature("OnlyCreatorCanRevealTheirMove()")
        );
        vm.prank(Elizabeth);
        rps.revealMove(0, Move.ROCK, 0);
    }

    function testRevealMoveWithIncorrectMove() public {
        uint256 nonce = 17;
        Move move = Move.ROCK;
        bytes32 commitHash = keccak256(abi.encodePacked(Sawmon, move, nonce));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        vm.warp(1 hours);

        vm.prank(Cristiano);
        rps.joinGame{value: fee}(0, Move.PAPER);

        vm.expectRevert(abi.encodeWithSignature("MoveDoesNotMatchCommit()"));
        vm.prank(Sawmon);
        rps.revealMove(0, Move.PAPER, nonce);
    }

    function testRevealMoveWithIncorrectMove(uint256 _nonce) public {
        uint256 nonce = 17;
        Move move = Move.ROCK;
        bytes32 commitHash = keccak256(abi.encodePacked(Sawmon, move, nonce));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        vm.warp(1 hours);

        vm.prank(Cristiano);
        rps.joinGame{value: fee}(0, Move.PAPER);

        vm.expectRevert(abi.encodeWithSignature("MoveDoesNotMatchCommit()"));
        vm.prank(Sawmon);
        vm.assume(nonce != _nonce);
        rps.revealMove(0, move, _nonce);
    }

    function testRevealMoveWithCorrectParameters(uint256 nonce) public {
        Move move = Move.ROCK;
        bytes32 commitHash = keccak256(abi.encodePacked(Sawmon, move, nonce));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        vm.warp(1 hours);

        vm.prank(Cristiano);
        rps.joinGame{value: fee}(0, Move.PAPER);

        vm.prank(Sawmon);
        rps.revealMove(0, move, nonce);

        (, , Move creatorMove, , , , ) = rps.games(0);
        assertTrue(creatorMove == move);
    }

    function testFinalizeWithGameNotStarted(uint256 gameId) public {
        vm.expectRevert(abi.encodeWithSignature("GameIsNotStarted()"));
        rps.finalize(gameId);
    }

    function testFinalizeWithGameNotExpiredAndNoOpponent(uint256 nonce) public {
        Move move = Move.ROCK;
        bytes32 commitHash = keccak256(abi.encodePacked(Sawmon, move, nonce));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        vm.expectRevert(abi.encodeWithSignature("GameIsNotExpired()"));
        rps.finalize(0);
    }

    // TODO more tests for finalize + poolAmount + test tx lock for sendETH

    function testFinalizeWithOpponentAndCreatorMoveNotRevealed(uint256 nonce)
        public
    {
        Move move = Move.ROCK;
        bytes32 commitHash = keccak256(abi.encodePacked(Sawmon, move, nonce));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        vm.prank(Cristiano);
        rps.joinGame{value: fee}(0, Move.ROCK);

        vm.expectRevert(
            abi.encodeWithSignature("GameCreatorMoveIsNotRevealed()")
        );
        vm.prank(Elizabeth);
        rps.finalize(0);
    }

    function testFinalizeAndIsADraw(uint256 nonce) public {
        uint256 sawmonBalanceInitial = address(Sawmon).balance;
        uint256 cristianoBalanceInitial = address(Cristiano).balance;
        (
            uint256 gameId,
            uint256 initialPoolAmount,
            bytes32 commitHash
        ) = _setupGame(
                Sawmon,
                Cristiano,
                Move.ROCK,
                Move.ROCK,
                nonce
            );

        vm.expectEmit(true, true, true, false);
        emit Tied(gameId, Sawmon, Cristiano);

        vm.prank(Natalie);
        rps.finalize(gameId);

        (
            GameStatus status,
            address creator,
            Move creatorMove,
            Move opponentMove,
            address opponent,
            bytes32 creatorCommitHash,
            uint256 startTime
        ) = rps.games(gameId);

        assertTrue(status == GameStatus.ENDED);
        assertTrue(creatorMove == opponentMove);
        assertEq(
            sawmonBalanceInitial - address(Sawmon).balance,
            fee / 2
        );
        assertEq(
            cristianoBalanceInitial - address(Cristiano).balance,
            fee / 2
        );
        assertEq(rps.poolAmount() - initialPoolAmount, fee + (fee % 2) * 2);
        assertEq(creator, Sawmon);
        assertEq(opponent, Cristiano);
        assertEq(creatorCommitHash, commitHash);
        assertEq(startTime, block.timestamp);
    }

    function testFinalizeAndCreatorWinsRockOverScissor(uint256 nonce) public {
        uint256 sawmonBalanceInitial = address(Sawmon).balance;
        uint256 cristianoBalanceInitial = address(Cristiano).balance;
        (
            uint256 gameId,
            uint256 initialPoolAmount,
            bytes32 commitHash
        ) = _setupGame(
                Sawmon,
                Cristiano,
                Move.ROCK,
                Move.SCISSOR,
                nonce
            );

        vm.expectEmit(true, true, false, false);
        emit Won(gameId, Sawmon);

        vm.prank(Elizabeth);
        rps.finalize(gameId);

        (
            GameStatus status,
            address creator,
            Move creatorMove,
            Move opponentMove,
            address opponent,
            bytes32 creatorCommitHash,
            uint256 startTime
        ) = rps.games(gameId);

        assertTrue(status == GameStatus.ENDED);
        assertTrue(creatorMove == Move.ROCK);
        assertTrue(opponentMove == Move.SCISSOR);
        assertEq(
            address(Sawmon).balance - sawmonBalanceInitial,
            fee  + initialPoolAmount
        );
        assertEq(
            cristianoBalanceInitial - address(Cristiano).balance,
            fee
        );
        assertEq(rps.poolAmount(), 0);
        assertEq(creator, Sawmon);
        assertEq(opponent, Cristiano);
        assertEq(creatorCommitHash, commitHash);
        assertEq(startTime, block.timestamp);
    }

    function testFinalizeAndOpponentWinsScissorOverPaper(uint256 nonce) public {
        uint256 sawmonBalanceInitial = address(Sawmon).balance;
        uint256 cristianoBalanceInitial = address(Cristiano).balance;
        (
            uint256 gameId,
            uint256 initialPoolAmount,
            bytes32 commitHash
        ) = _setupGame(
                Sawmon,
                Cristiano,
                Move.PAPER,
                Move.SCISSOR,
                nonce
            );

        vm.expectEmit(true, true, false, false);
        emit Won(gameId, Cristiano);

        vm.prank(Natalie);
        rps.finalize(gameId);

        (
            GameStatus status,
            address creator,
            Move creatorMove,
            Move opponentMove,
            address opponent,
            bytes32 creatorCommitHash,
            uint256 startTime
        ) = rps.games(gameId);

        assertTrue(status == GameStatus.ENDED);
        assertTrue(creatorMove == Move.PAPER);
        assertTrue(opponentMove == Move.SCISSOR);
        assertEq(sawmonBalanceInitial - address(Sawmon).balance, fee);
        assertEq(
            address(Cristiano).balance - cristianoBalanceInitial,
            fee + initialPoolAmount
        );
        assertEq(rps.poolAmount(), 0);
        assertEq(creator, Sawmon);
        assertEq(opponent, Cristiano);
        assertEq(creatorCommitHash, commitHash);
        assertEq(startTime, block.timestamp);
    }

    function testFinalizeAndAfterGameExpiredWithNoOpponent(uint256 nonce)
        public
    {
        vm.warp(0);
        Move move = Move.PAPER;
        bytes32 commitHash = keccak256(abi.encodePacked(Sawmon, move, nonce));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);
        uint256 sawmonBalanceAfterStartGame = address(Sawmon).balance;

        uint256 gameId = 0;
        uint256 poolAmountInitial = rps.poolAmount();
        uint256 initialTimestamp = block.timestamp;

        vm.warp(rps.MAX_GAME_DURATION());

        vm.expectEmit(true, false, false, false);
        emit GameExpired(gameId);

        vm.prank(Elizabeth);
        rps.finalize(gameId);

        (
            GameStatus status,
            address creator,
            ,
            ,
            address opponent,
            bytes32 creatorCommitHash,
            uint256 startTime
        ) = rps.games(gameId);

        assertTrue(status == GameStatus.ENDED);
        assertEq(address(Sawmon).balance - sawmonBalanceAfterStartGame, fee);
        assertEq(rps.poolAmount(), poolAmountInitial);
        assertEq(creator, Sawmon);
        assertEq(opponent, address(0));
        assertEq(creatorCommitHash, commitHash);
        assertEq(startTime, initialTimestamp);
    }

    function testFinalizeWinAfterADraw(uint256 nonce1, uint256 nonce2) public {
        (uint256 gameId1,,) = _setupGame(
                Sawmon,
                Cristiano,
                Move.PAPER,
                Move.PAPER,
                nonce1
            );

        vm.prank(Natalie);
        rps.finalize(gameId1);

        vm.warp(rps.MAX_GAME_DURATION());

        uint256 natalieBalanceInitial = address(Natalie).balance;
        uint256 elizabethBalanceInitial = address(Elizabeth).balance;
        (
            uint256 gameId2,
            uint256 initialPoolAmount2,
            bytes32 commitHash2
        ) = _setupGame(
                Natalie,
                Elizabeth,
                Move.PAPER,
                Move.SCISSOR,
                nonce2
            );

        vm.expectEmit(true, true, false, false);
        emit Won(gameId2, Elizabeth);

        vm.prank(Natalie);
        rps.finalize(gameId2);

        (
            GameStatus status,
            address creator,
            Move creatorMove,
            Move opponentMove,
            address opponent,
            bytes32 creatorCommitHash,
            uint256 startTime
        ) = rps.games(gameId2);

        assertTrue(status == GameStatus.ENDED);
        assertTrue(creatorMove == Move.PAPER);
        assertTrue(opponentMove == Move.SCISSOR);
        assertEq(natalieBalanceInitial - address(Natalie).balance, fee);
        assertEq(
            address(Elizabeth).balance - elizabethBalanceInitial,
            fee + initialPoolAmount2
        );
        assertEq(rps.poolAmount(), 0);
        assertEq(creator, Natalie);
        assertEq(opponent, Elizabeth);
        assertEq(creatorCommitHash, commitHash2);
        assertEq(startTime, block.timestamp);
    }

    function testFinalizeReenterencyForWinner(uint256 nonce) public {
        uint256 sawmonBalanceInitial = address(Sawmon).balance;
        uint256 badActorBalanceInitial = address(badActor).balance;
        (
            uint256 gameId,
            uint256 initialPoolAmount,
            bytes32 commitHash
        ) = _setupGame(
                address(badActor),
                Sawmon,
                Move.PAPER,
                Move.ROCK,
                nonce
            );

        vm.expectEmit(true, true, false, false);
        emit Won(gameId, address(badActor));

        vm.prank(Natalie);
        rps.finalize(gameId);

        (
            GameStatus status,
            address creator,
            Move creatorMove,
            Move opponentMove,
            address opponent,
            bytes32 creatorCommitHash,
            uint256 startTime
        ) = rps.games(gameId);

        assertTrue(status == GameStatus.ENDED);
        assertTrue(creatorMove == Move.PAPER);
        assertTrue(opponentMove == Move.ROCK);
        assertEq(sawmonBalanceInitial - address(Sawmon).balance, fee);
        assertEq(
            address(badActor).balance - badActorBalanceInitial,
            fee + initialPoolAmount
        );
        assertEq(rps.poolAmount(), 0);
        assertEq(creator, address(badActor));
        assertEq(opponent, Sawmon);
        assertEq(creatorCommitHash, commitHash);
        assertEq(startTime, block.timestamp);
    }

    function testFinalizeReenterencyForLoser(uint256 nonce) public {
        uint256 sawmonBalanceInitial = address(Sawmon).balance;
        uint256 badActorBalanceInitial = address(badActor).balance;
        (
            uint256 gameId,
            uint256 initialPoolAmount,
            bytes32 commitHash
        ) = _setupGame(
                address(badActor),
                Sawmon,
                Move.SCISSOR,
                Move.ROCK,
                nonce
            );

        vm.expectEmit(true, true, false, false);
        emit Won(gameId, address(Sawmon));

        vm.prank(Elizabeth);
        rps.finalize(gameId);

        (
            GameStatus status,
            address creator,
            Move creatorMove,
            Move opponentMove,
            address opponent,
            bytes32 creatorCommitHash,
            uint256 startTime
        ) = rps.games(gameId);

        assertTrue(status == GameStatus.ENDED);
        assertTrue(creatorMove == Move.SCISSOR);
        assertTrue(opponentMove == Move.ROCK);
        assertEq(badActorBalanceInitial - address(badActor).balance, fee);
        assertEq(
            address(Sawmon).balance - sawmonBalanceInitial,
            fee + initialPoolAmount
        );
        assertEq(rps.poolAmount(), 0);
        assertEq(creator, address(badActor));
        assertEq(opponent, Sawmon);
        assertEq(creatorCommitHash, commitHash);
        assertEq(startTime, block.timestamp);
    }

    function testFinalizeReenterencyWhenDraw(uint256 nonce) public {
        uint256 sawmonBalanceInitial = address(Sawmon).balance;
        uint256 badActorBalanceInitial = address(badActor).balance;
        (
            uint256 gameId,
            uint256 initialPoolAmount,
            bytes32 commitHash
        ) = _setupGame(
                address(badActor),
                Sawmon,
                Move.ROCK,
                Move.ROCK,
                nonce
            );

        vm.expectEmit(true, true, false, false);
        emit Tied(gameId, address(badActor), address(Sawmon));

        vm.prank(address(badActor));
        rps.finalize(gameId);

        (
            GameStatus status,
            address creator,
            Move creatorMove,
            Move opponentMove,
            address opponent,
            bytes32 creatorCommitHash,
            uint256 startTime
        ) = rps.games(gameId);

        assertTrue(status == GameStatus.ENDED);
        assertTrue(creatorMove == Move.ROCK);
        assertTrue(opponentMove == Move.ROCK);
        assertEq(badActorBalanceInitial - address(badActor).balance, fee/2);
        assertEq(sawmonBalanceInitial - address(Sawmon).balance, fee/2);
        assertEq(rps.poolAmount(), initialPoolAmount + fee + (fee % 2) * 2);
        assertEq(creator, address(badActor));
        assertEq(opponent, Sawmon);
        assertEq(creatorCommitHash, commitHash);
        assertEq(startTime, block.timestamp);
    }

    function testIsGameExpiredAfterMaxGameDuration(uint256 dt) public {
        vm.warp(0);

        bytes32 commitHash = bytes32(uint256(0xba29));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        vm.assume(dt >= rps.MAX_GAME_DURATION());
        vm.warp(dt);

        assertEq(rps.isGameExpired(0), true);
    }

    function testIsGameExpiredBeforeMaxGameDuration(uint256 dt) public {
        vm.warp(0);

        bytes32 commitHash = bytes32(uint256(0xba29));
        vm.prank(Sawmon);
        rps.startGame{value: fee}(commitHash);

        vm.assume(dt < rps.MAX_GAME_DURATION());
        vm.warp(dt);

        assertEq(rps.isGameExpired(0), false);
    }
}
