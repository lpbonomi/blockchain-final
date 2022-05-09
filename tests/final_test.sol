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
        testVote.addParticipant();
        try testVote.addParticipant() {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Participant already registered.", "");
        } 
    }

    function checkAddProposal() public {
        try testVote.addProposal("Title can't be empty", "This is a test proposal", 1000, address(0x0)) {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Voting is not open yet.", "");
        } 

        testVote.openVoting();

        try testVote.addProposal("Title can't be empty", "This is a test proposal", 1000, address(0x0)) {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Address not registered!", "");
        } 

        testVote.addParticipant();

        try testVote.addProposal("", "This is a test proposal", 1000, address(0x0)) {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Title can't be empty", "");
        } 

        try testVote.addProposal("Proposal Title", "", 1000, address(0x0)) {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Description can't be empty", "");
        } 

        try testVote.addProposal("Proposal Title", "This is a test proposal", 1000, address(0x0)) {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "The address received is not a valid contract address", "");
        } 

        testVote.addProposal("Proposal Title", "This is a test proposal", 1000, address(this));
    }
}