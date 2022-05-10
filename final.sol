// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./openzeppelin-contracts-master/contracts/token/ERC20/ERC20.sol";

contract QuadraticVoting{
    address owner;
    bool is_open;
    mapping (address => uint) tokens_of_voters;
    Proposal[] proposals;
    VotingToken private tokenLogic;
    mapping (address => bool) registeredParticipants; 
    uint total_participants;
    uint private immutable tokenPrice;
    uint private maxUsedTokens;
    uint private total_budget;
    // Proposal -> User -> votes
    mapping(uint => mapping(address => uint)) votes_per_user_per_proposal;
    address[][] voters_of_proposals;


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


    constructor(uint tokenPrice_, uint maxUsedTokens_) payable{
        owner = msg.sender;
        tokenPrice = tokenPrice_;
        maxUsedTokens = maxUsedTokens_;
        total_budget = msg.value;
        tokenLogic = new VotingToken("Mark", "RM", maxUsedTokens_);
        is_open = false;
        total_participants = 0;
        voters_of_proposals = new address[][](0);
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
        require(!is_open, "Voting is already open.");
        is_open = true;
        total_budget = msg.value;
    }

    function addParticipant() external payable {
        require(registeredParticipants[msg.sender] == false, "Participant already registered.");
        registeredParticipants[msg.sender] = true;
        total_participants++;
    }
    
    function addProposal(string calldata title, string calldata description, uint budget, address executable_proposal_address) external votingOpen participantRegistered returns (uint proposal_id  ){
        require(bytes(title).length > 0, "Title can't be empty");
        require(bytes(description).length > 0, "Description can't be empty");
        require(isContract(executable_proposal_address), "The address received is not a valid contract address");

        proposals.push(Proposal(msg.sender, title, description, 0, budget, executable_proposal_address, false, false));
        voters_of_proposals.push(new address[](0));
        return proposals.length - 1;
    }

    function isContract (address a) private view returns (bool){
        uint size;
        assembly{
            size := extcodesize(a)
        }
        return (size != 0);
    }
    
    function cancelProposal(uint proposal_id) external votingOpen onlyProposalOwner(proposal_id){
        Proposal storage proposal = proposals[proposal_id];

        require(!proposal.is_approved, "Approved proposals can't be cancelled.");
        require(!proposal.is_cancelled, "Proposal has already been cancelled.");

        proposal.is_cancelled = true;
        
        address[] storage voters_of_proposal = voters_of_proposals[proposal_id];

        for(uint i = 0; i < voters_of_proposal.length; i++){
            uint votes = votes_per_user_per_proposal[proposal_id][voters_of_proposal[i]];
            votes_per_user_per_proposal[proposal_id][voters_of_proposal[i]] = 0;
            tokens_of_voters[voters_of_proposal[i]] += votes**2;
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
            if(!proposal.is_cancelled && !proposal.is_approved && proposal.budget != 0){
                number_of_pending_proposals++;
            }
        }

        pending_proposals = new uint[](number_of_pending_proposals);
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
            if(proposal.is_approved && proposal.budget != 0){
                number_of_approved_proposals++;
            }
        }

        approved_proposals = new uint[](number_of_approved_proposals);
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

        signaling_proposals = new uint[](number_of_signaling_proposals);
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

    function stake(uint proposalId, uint nrVotes) public participantRegistered votingOpen{
        Proposal storage proposal = proposals[proposalId];
        uint previous_votes = votes_per_user_per_proposal[proposalId][msg.sender];
        uint nrTokens = (previous_votes + nrVotes)**2 - previous_votes;

        require(tokens_of_voters[msg.sender]>=nrTokens, "Not enough tokens!");
        require(tokenLogic.allowance(msg.sender, address(this))>=nrTokens, "Use of tokens needs allowance!");
        tokenLogic.transferFrom(msg.sender, address(this), nrTokens);
        tokens_of_voters[msg.sender] -= nrTokens;

        votes_per_user_per_proposal[proposalId][msg.sender] += nrVotes;
        proposal.votes += nrVotes;

        if(previous_votes == 0){
            voters_of_proposals[proposalId].push(msg.sender);
        }
        _checkAndExecuteProposal(proposalId);  
    }

    function getProposalInfo(uint proposal_id) public view returns(string memory, string memory, uint, address){
        Proposal storage proposal = proposals[proposal_id];
        
        return (proposal.title, proposal.description, proposal.budget, proposal.executable_proposal_address);
    }

    function withdrawFromProposal(uint amount_of_votes, uint proposal_id) external{
        Proposal storage proposal = proposals[proposal_id];
        require(!proposal.is_approved, "The proposal has already been approved");
        require(votes_per_user_per_proposal[proposal_id][msg.sender] >= amount_of_votes, "User has not casted that much votes.");

        uint votes = votes_per_user_per_proposal[proposal_id][msg.sender];
        votes_per_user_per_proposal[proposal_id][msg.sender] = amount_of_votes;
        tokens_of_voters[msg.sender] += ((votes**2) - ((votes - amount_of_votes)**2)) ;
    }

// TODO
// Recuerda que debe actualizarse el presupuesto disponible para propuestas (y no olvides a˜nadir al presupuesto el
//  importe recibido de los tokens de votos de la propuesta que se acaba de aprobar).
    
    function _checkAndExecuteProposal(uint proposal_id) internal {
        Proposal storage proposal = proposals[proposal_id];
        require(proposal.budget <= total_budget + (proposal.votes * tokenPrice), "Budget + money collected is not enough for proposal.");

        // TODO question: numProposals includes cancelled proposals?
        // We multiply by 10 and by total_budget to avoid decimals
        uint threshold = (2 + (10 * proposal.budget)) * total_participants + (proposals.length * 10 * total_budget);
        require(proposal.votes * 10 * total_budget > threshold, "Votes don't exceed the threshold");

        IExecutableProposal executable_proposal = IExecutableProposal(proposal.executable_proposal_address);
        executable_proposal.executeProposal{value: proposal.budget, gas: 100000}(proposal_id);

        proposal.is_approved = true;

        address[] storage voters_of_proposal = voters_of_proposals[proposal_id];
        
        for(uint i = 0; i < voters_of_proposal.length; i++){
            uint votes = votes_per_user_per_proposal[proposal_id][voters_of_proposal[i]];
            tokenLogic.burn(voters_of_proposal[i], votes**2);
        }
    }

    function closeVoting() external onlyOwner{
        is_open = false;
        for(uint i = 0 ; i < proposals.length; i++)
        {
            if(proposals[i].is_approved == false) //if the proposal is still not approved
            {
               for(uint j=0; j<voters_of_proposals[i].length; j++)
                {
                    if(votes_per_user_per_proposal[i][voters_of_proposals[i][j]]>0) //check if the participant voted in this proposal
                    {
                        uint aux = votes_per_user_per_proposal[i][voters_of_proposals[i][j]];
                        votes_per_user_per_proposal[i][voters_of_proposals[i][j]] = 0; //set the number of tokens to 0 
                        address payable addr = payable(voters_of_proposals[i][j]); //convert the address to payable to be able to do the transfer
                        addr.transfer(aux**2*tokenPrice); //send him the value in money of his tokens
                        delete proposals[i];
                    }
                }
            }
        }
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

interface IExecutableProposal 
{
    function executeProposal(uint proposalId) external payable;
}

contract testContract is IExecutableProposal
{ 
    event Pay(address sender, uint proposalId, uint value);
    
    function executeProposal(uint proposalId) override external payable
    {
        emit Pay(msg.sender, proposalId, msg.value);
    }
}


