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
    // #value: 0
    function checkBuyTooFewTokens() public payable {
        testVote.addParticipant();
        try testVote.buyTokens() {
            Assert.ok(false, "Call should fail");
        } catch Error(string memory reason) {
            Assert.equal(reason, "You have to buy at least one token!", "");
        }    
    }

    // #sender: account-1
    // #value: 1000
    function checkBuyTokensUnregistered() public payable {
        try testVote.buyTokens() {
            Assert.ok(false, "Call should fail");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Address not registered!", "");
        }    
    }

    /// #sender: account-1
    /// #value: 3001
    function checkBuyFractionalTokens() public payable {
        testVote.addParticipant();
        try testVote.buyTokens{value: 3001}() {
            Assert.ok(false, "Call should fail");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Watch the token price, only whole tokens can be bought!", "");
        }  
    }

    /// #sender: account-1
    /// #value: 11000
    function checkBuyTooManyTokens() public payable {
        testVote.addParticipant();
        try testVote.buyTokens{value: 11000}() {
            Assert.ok(false, "Call should fail");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Not enough tokens available!", "");
        }  
    }
    
    /*
    /// #sender: account-1
    /// #value: 10000
    function buyCorrectTokens() public payable {
        testVote.addParticipant();
        testVote.buyTokens{value: 5000}();
        Assert.equal(tokens_of_voters[msg.sender], 5, "");
    }
    */

    // #sender: account-1
    // #value: 10000
    //function sellTooManyTokens() public payable {
        //testVote.addParticipant;
        //testVote.buyTokens{gas: 100000, value: 1000}();
        /*try testVote.sellTokens(2) {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "You don't own so many tokens!", "");
        }*/
    //}

    // #sender: account-1
    // #value: 10000
    function sellCorrectTokens() public {
        testVote.addParticipant;
        testVote.buyTokens{value: 1000}();
        Assert.equal(tokens_of_voters[msg.sender], 1, "");
        testVote.sellTokens(1);
        Assert.equal(tokens_of_voters[msg.sender], 0, "");
    }

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

    function checkCancelProposal() public {
        testVote.openVoting();
        testVote.addParticipant();
        uint proposal_id = testVote.addProposal("Proposal Title", "This is a test proposal", 1000, address(this));

        testVote.cancelProposal(proposal_id);
        try testVote.cancelProposal(proposal_id) {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Proposal has already been cancelled.", "");
        } 
    }

    function checkGetProposals() public {
        testVote.openVoting();
        testVote.addParticipant();

        Assert.equal(testVote.getPendingProposals().length, 0, "The number of proposals should be 0.");
        Assert.equal(testVote.getApprovedProposals().length, 0, "The number of proposals should be 0.");

        testVote.addProposal("Proposal Title", "This is a test proposal", 1000, address(this));

        Assert.equal(testVote.getPendingProposals().length, 1, "The number of proposals should be 1.");
    }

    
    

}
