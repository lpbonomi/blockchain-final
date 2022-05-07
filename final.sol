// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

contract QuadraticVoting {
    address owner;
    bool is_open;
    uint initial_budget;
    mapping (address => uint) tokens_of_voters;
    mapping (uint => Proposal) proposals;
    VotingToken private tokenLogic;
    mapping (address => bool) registeredParticipants; 
    uint private immutable tokenPrice;
    uint private maxUsedTokens;
    uint private totalbudget;
    // Proposal -> User -> votes
    mapping(address => mapping(address => uint)) votes_per_user_per_proposal;
    mapping(address => address[]) voters_of_proposals;


    struct Proposal {
        address owner;
        string title;
        string description;
        uint votes;
        uint budget;
        address executable_proposal_address;
        bool is_approved;
        bool is_cancelled;
    }


    constructor(uint tokenPrice_, uint maxUsedTokens_, uint tokenCap){
        owner = msg.sender;
        tokenPrice = tokenPrice_;
        maxUsedTokens = maxUsedTokens_;
        totalbudget = msg.value;
        tokenLogic = new VotingToken("Mark", "RM", tokenCap);
        is_open = false;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    modifier participantRegistered {
        require(registeredParticipants[msg.sender], "Address not registered!");
        _;
    }

    modifier onlyProposalOwner(uint proposal_id) {
        require(proposals[proposal_id].owner == msg.sender, "Only the owner of the proposal can call this function.");
        _;
    }

    modifier votingOpen {
        require(is_open, "Voting is not open yet.");
        _;
    }

    function openVoting() external payable onlyOwner{
        is_open = true;
        initial_budget = msg.value;
    }

    function addParticipant() external payable {
        require(registeredParticipants[msg.sender] == false, "Participant already registered.");
        buyTokens();
        registeredParticipants[msg.sender] = true;
    }
    
    function addProposal(string calldata title, string calldata description, uint budget, address executable_proposal_address) external votingOpen participantRegistered returns (uint proposal_id  ){
        require(bytes(title).length > 0, "Title can't be empty");
        require(bytes(description).length > 0, "Title can't be empty");
        require(isContract(), "The address received is not a valid contract address");

        proposals.push(Proposal(msg.sender, title, description, 0, budget, executable_proposal_address, false, false));
        return proposals.length - 1;
    }

    function isContract (address a) private returns (bool){
        uint size;
        assembly{
            size := extcodesize(a)
        }
        return (size != 0);
    }
    
    function cancelProposal(uint proposal_id) external votingOpen onlyProposalOwner(proposal_id){
        Proposal proposal = proposals[proposal_id];

        require(!proposal.is_approved, "Approved proposals can't be cancelled.");
        require(!proposal.is_cancelled, "Proposal has already been cancelled.");

        proposal.is_cancelled = true;
        
        voters_of_proposal = voters_of_proposals[proposal.address];

        for(uint i = 0; i < voters_of_proposal.length; i++){
            uint votes = votes_per_user_per_proposal[proposal.address][voters_of_proposal[i]];
            votes_per_user_per_proposal[proposal.address][voters_of_proposal[i]] = 0;
            tokens_of_voters[voters_of_proposal[i]] =+ votes**2;
        }
    }

    function buyTokens() participantRegistered public payable
    {
        require(msg.value>0, "You have to buy at least one token!");
        require((msg.value % tokenPrice)==0, "Watch the token price, only whole tokens can be bought!");
        require(msg.value/tokenPrice <= maxUsedTokens, "Not enough tokens available!");
        tokenLogic.mint(msg.sender, msg.value/tokenPrice);
        tokens_of_voters[msg.sender] += msg.value/tokenPrice;
        maxUsedTokens -= msg.value/tokenPrice;
    }

    function sellTokens(uint nrTokens) participantRegistered public payable
    {
        require(tokens_of_voters[msg.sender] >= nrTokens, "You don't own so many tokens!"); 
        tokenLogic.burn(msg.sender, nrTokens);
        address payable addr = payable(msg.sender);
        addr.transfer(nrTokens*tokenPrice);       
    }

    function getERC20Voting() external view returns(VotingToken)
    {
        return tokenLogic;
    }

    // TODO ver si se puede hacer de una manera mejor
    function getPendingProposals() external view votingOpen returns (uint[] memory  pending_proposals){
        uint number_of_pending_proposals = 0;
        for(uint i = 0; i < proposals.length; i++){
            Proposal storage proposal = proposals[i];
            if(!proposal.is_cancelled && !proposal.is_approved){
                number_of_pending_proposals++;
            }
        }

        uint[] memory pending_proposals = new uint[](number_of_pending_proposals);
        uint j = 0;
        for(uint i = 0; i < number_of_pending_proposals; j++){
            Proposal storage proposal = proposals[i];
            if(!proposal.is_cancelled && !proposal.is_approved){
                pending_proposals[i] = j;
                i++;
            }
        }

        return pending_proposals;
    }

    function getApprovedProposals() external view votingOpen returns(uint[] memory approved_proposals){
        uint number_of_approved_proposals = 0;
        for(uint i = 0; i < proposals.length; i++){
            Proposal storage proposal = proposals[i];
            if(proposal.is_approved){
                number_of_approved_proposals++;
            }
        }

        uint[] memory approved_proposals = new uint[](number_of_approved_proposals);
        uint j = 0;
        for(uint i = 0; i < number_of_approved_proposals; j++){
            Proposal storage proposal = proposals[i];
            if(!proposal.is_cancelled && !proposal.is_approved){
                approved_proposals[i] = j;
                i++;
            }
        }

        return approved_proposals;
    }

    function getSignalingProposals() external view votingOpen returns(uint[] memory signaling_proposals){
        uint number_of_signaling_proposals = 0;
        for(uint i = 0; i < proposals.length; i++){
            Proposal storage proposal = proposals[i];
            if(proposal.budget == 0){
                number_of_signaling_proposals++;
            }
        }

        uint[] memory signaling_proposals = new uint[](number_of_signaling_proposals);
        uint j = 0;
        for(uint i = 0; i < number_of_signaling_proposals; j++){
            Proposal storage proposal = proposals[i];
            if(!proposal.is_cancelled && !proposal.is_approved){
                signaling_proposals[i] = j;
                i++;
            }
        }

        return signaling_proposals;
    }

    function getSignalingProposals(uint proposal_id) external view votingOpen returns(string memory title, string memory description, uint budget){
        Proposal storage proposal = proposals[proposal_id];
        return (proposal.title, proposal.description, proposal.budget);
    }

    function stake(uint proposalId, uint nrVotes) public participantRegistered {
        require(votingOpen == true, "The voting has not started yet!");        
        uint nrTokens;
        if(proposals[proposalId].votes_per_user[msg.sender]>0) {
            uint currentVotes = proposals[proposalId].votes_per_user[msg.sender];
            nrTokens = (currentVotes+nrVotes)**2 - currentVotes;
        } else {
            nrTokens = nrVotes**2;
        }

        require(tokens_of_voters[msg.sender]>=nrTokens, "Not enough tokens!");
        require(tokenLogic.allowance(msg.sender, address(this))>=nrTokens, "Use of tokens needs allowance!");
        tokenLogic.transferFrom(msg.sender, address(this), nrTokens);
        tokens_of_voters[msg.sender] -= nrTokens;
        proposals[proposalId].votes_per_user[msg.sender] += nrVotes;
        proposals[proposalId].votes += nrVotes;
        _checkAndExecuteProposal(proposalId);  
    }


this function removes (if possible) that amount of votes previously
     casted by the participant invoking this function. A participant can only remove votes that he has previously casted for that proposal, 
     and the proposal cannot have been approved yet. Remember that this function must return the tokens used for casting those votes back to
      the participant (for instance, if the participant had casted 4 votes for a proposal and withdraws 2 of them, 12 tokens must be returned
       back to the participant).


    function withdrawFromProposal(uint amount_of_votes, uint proposal_id) external{
        Proposal storage proposal = proposals[proposal_id];
        require(!proposal.is_approved, "The proposal has already been approved");
        require(votes_per_user_per_proposal[proposal.address][msg.sender] >= amount_of_votes, "User has not casted that much votes.");

        uint votes = votes_per_user_per_proposal[proposal.address][voters_of_proposal[i]];
        votes_per_user_per_proposal[proposal.address][voters_of_proposal[i]] =- amount_of_votes;
        tokens_of_voters[voters_of_proposal[i]] =+ ((votes**2) - ((votes - amount_of_votes)**2)) ;
    }


// _checkAndExecuteProposal: internal function that checks if the conditions for execu- ting a proposal hold and, if they hold, executes it using 
// the function executeProposal from the contract provided when this proposal was created. This call to the external contract must transfer the
//  budgeted amount for executing the proposal. Remember that the total amount available for proposals must be updated (and do not forget the
//   amount received for the tokens used for voting the proposal that is to be executed). Besides, the tokens related to votes for this proposal
//    must be removed, as its execution consumes them.

// When calling to executeProposal in the external contract, the maximum amount of gas must be limited to prevent the proposal contract from
//  consuming all the gas in the transaction. This call must consume at most 100000 gas.

    // funciton _checkAndcheckAndExecuteProposal() internal {
    //         //Perform checks
    //         //Execute
    //         // TODO etc
    // }

    function closeVoting() external onlyOwner{
        is_open = false;

        //         • The proposals that have not been approved must be dismissed and the tokens used for voting them must be 
        // returned to their owners.
        // • The signaling proposals must be executed (no Ether is transferred in this case) and the tokens used for voting 
        // them must be returned to their owners.
        // • The remaining voting budget not spent on any proposal must be transferred to the owner of the voting contract.


        // When a voting process is closed, new proposals and votes must be rejected and the QuadraticVoting contract must
        //  be set to a state that allows opening a new voting process.
        // This function might consume a lot of gas, take this into account when programming and testing it.
    }

    function sqrt(uint x) internal pure returns (uint y) 
    {
        uint z = (x + 1) / 2;
         y = x;
        while (z < y) 
        {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}

contract VotingToken is ERC20
{
    uint256 immutable private _cap;
    constructor (string memory name_, string memory symbol_, uint256 cap) ERC20(name_, symbol_) 
    {
        _cap = cap;
    }
    
    function mint(address account, uint256 amount) external  virtual {
        require(ERC20.totalSupply() + amount <= _cap, "ERC20C: cap exceeded");  //totalSupply of tokens bought already + the new tokens;
        super._mint(account, amount);
    }
    
    function burn(address sender, uint256 amount) public virtual{
        super._burn(sender, amount);
    }
    
}
