// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import "../final.sol";

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract testSuite {

    QuadraticVoting testVote;
    address acc0 = TestsAccounts.getAccount(0); //owner by default
    address acc1 = TestsAccounts.getAccount(1);
    address acc2 = TestsAccounts.getAccount(2);
    address acc3 = TestsAccounts.getAccount(3);
    address recipient = TestsAccounts.getAccount(4);

    function beforeEach() public {
        testVote = new QuadraticVoting(1000, 10);
    }

    // #sender: account-1
    // #value: 10000
    // function checkBuyTokens() public payable {
    //     testVote = new QuadraticVoting(1000, 10);
    //     addParticipant();
    //     Assert.equal(msg.value, 0, "kein Plan");
    // }

    // #sender: account-1
    // #value: 10000
    function checkOpenVoting() public {
        testVote = new QuadraticVoting(1000, 10);
        testVote.openVoting();
        try testVote.openVoting() {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Voting is already open.", "");
        } 
    }

    // #sender: account-1
    // #value: 10000
    function checkAddParticipant() public {
        testVote = new QuadraticVoting(1000, 10);
        testVote.addParticipant();
        try testVote.addParticipant() {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Participant already registered.", "");
        } 
    }
}