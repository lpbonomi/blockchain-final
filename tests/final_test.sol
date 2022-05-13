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
        testVote = new QuadraticVoting(10, 10000);
    }

    /// #sender: account-1
    /// #value: 1000000
    function completeTest() public payable{
        testVote.openVoting{value: 10000}();
        testVote.addParticipant{value:10000}();
        TestContract TC = new TestContract();
        uint proposal_id = testVote.addProposal("Proposal Title", "This is a test proposal", 1000, address(TC));
        testVote.buyTokens{value: 1000}();
        testVote.getPendingProposals();
        testVote.tokenLogic().approve(address(testVote), uint(100));
        testVote.stake(proposal_id, 10);
        testVote.getSignalingProposals();
        testVote.closeVoting();
    }
    
    /// #sender: account-1
    /// #value: 10000
    function checkBuyTooLittleTokens() public payable {
        testVote.addParticipant{value:10}();
        try testVote.buyTokens{value:0}() {
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
        testVote.addParticipant{value:10}();
        try testVote.buyTokens{value:5}() {
            Assert.ok(false, "Call should fail");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Watch the token price, only whole tokens can be bought!", "");
        }  
    }

    /// #sender: account-1
    /// #value: 10000
    function checkOpenVoting() public {
        testVote.openVoting();
        try testVote.openVoting() {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Voting is already open.", "");
        } 
    }

    /// #sender: account-1
    /// #value: 10000
    function checkAddParticipant() public {
        testVote.addParticipant{value:1000}();
        try testVote.addParticipant{value:1000}() {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Participant already registered.", "");
        } 
    }

    /// #sender: account-1
    /// #value: 10000
    function checkAddProposal() public payable {
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

        testVote.addParticipant{value:1000}();

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
        testVote.addParticipant{value:1000}();
        uint proposal_id = testVote.addProposal("Proposal Title", "This is a test proposal", 1000, address(this));

        testVote.cancelProposal(proposal_id);
        try testVote.cancelProposal(proposal_id) {
            Assert.ok(false, "Call should fail.");
        } catch Error(string memory reason) {
            Assert.equal(reason, "Proposal has already been cancelled.", "");
        } 
    }

    /// #sender: account-1
    /// #value: 10000
    function checkGetProposals() public payable{
        testVote.openVoting();
        testVote.addParticipant{value:1000}();

        Assert.equal(testVote.getPendingProposals().length, 0, "The number of proposals should be 0.");
        Assert.equal(testVote.getApprovedProposals().length, 0, "The number of proposals should be 0.");

        testVote.addProposal("Proposal Title", "This is a test proposal", 1000, address(this));
        testVote.addProposal("Proposal Title", "This is a test signaling proposal", 0, address(this));

        Assert.equal(testVote.getPendingProposals().length, 1, "The number of proposals should be 1.");
        Assert.equal(testVote.getSignalingProposals().length, 1, "The number of proposals should be 1.");
    }

    /// #sender: account-1
    /// #value: 10000
    function checkGetProposalInfo() public payable{
        testVote.openVoting();
        testVote.addParticipant{value:1000}();

        uint proposal_id = testVote.addProposal("Proposal Title", "This is a test proposal", 1000, address(this));

        (string memory title, string memory description, uint budget, address executable_proposal_address) = testVote.getProposalInfo(proposal_id);

        Assert.equal(title, "Proposal Title", "");
        Assert.equal(description, "This is a test proposal", "");
        Assert.equal(budget, 1000, "");
        Assert.equal(executable_proposal_address, address(this), "");
    }

    /// #sender: account-1
    /// #value: 100000
    function checkCloseVoting() public payable {
        testVote.openVoting{value: 10000}();
        testVote.addParticipant{value:10000}();

        TestContract TC = new TestContract();
        uint proposal_id = testVote.addProposal("Proposal Title", "This is a test proposal", 1000, address(TC));

        testVote.tokenLogic().approve(address(testVote), uint(100));
        testVote.stake(proposal_id, 10);
        testVote.closeVoting();
    }
}