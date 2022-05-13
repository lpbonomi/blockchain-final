// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

// Downloadable from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/
import "./openzeppelin-contracts-master/contracts/token/ERC20/ERC20.sol";
import "./openzeppelin-contracts-master/contracts/utils/math/SafeMath.sol";

contract QuadraticVoting{

    using SafeMath for uint256;
    address payable owner;
    bool is_open;
    mapping (address => uint) tokens_of_voters;
    Proposal[] proposals;
    VotingToken public tokenLogic;
    mapping (address => bool) registeredParticipants; 
    uint total_participants;
    uint private immutable tokenPrice;
    uint private maxUsedTokens;
    uint private total_budget;
    // Proposal -> User -> votes
    mapping(uint => mapping(address => uint)) votes_per_user_per_proposal;
    address payable[][] voters_of_proposals;

    // Vars for the resumable closeVoting()
    uint close_voting_i;
    uint close_voting_j;
    uint gas_per_iteration;


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


    constructor(uint tokenPrice_, uint maxUsedTokens_) payable {
        owner = payable(msg.sender);
        tokenPrice = tokenPrice_;
        maxUsedTokens = maxUsedTokens_;
        tokenLogic = new VotingToken("Mark", "RM", maxUsedTokens_);
        is_open = false;
        total_participants = 0;
        voters_of_proposals = new address payable[][](0);
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

        // Initializing resumable closeVoting() vars
        close_voting_i = 0;
        close_voting_j = 0;
        gas_per_iteration = 0;
    }

    function addParticipant() external payable {
        require(registeredParticipants[msg.sender] == false, "Participant already registered.");
        registeredParticipants[msg.sender] = true;
        total_participants++;
        buyTokens();
    }
    
    function addProposal(string calldata title, string calldata description, uint budget, address executable_proposal_address) external votingOpen participantRegistered returns (uint proposal_id  ){
        require(bytes(title).length > 0, "Title can't be empty");
        require(bytes(description).length > 0, "Description can't be empty");
        require(isContract(executable_proposal_address), "The address received is not a valid contract address");

        proposals.push(Proposal(msg.sender, title, description, 0, budget, executable_proposal_address, false, false));
        voters_of_proposals.push(new address payable[](0));
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
        
        address payable[] storage voters_of_proposal = voters_of_proposals[proposal_id];

        // Returns tokens to voters
        for(uint i = 0; i < voters_of_proposal.length; i++){
            uint votes = votes_per_user_per_proposal[proposal_id][voters_of_proposal[i]];
            tokens_of_voters[voters_of_proposal[i]] += votes**2;
            votes = 0;
        }
    }

    function buyTokens() participantRegistered public payable
    {
        require(msg.value>0, "You have to buy at least one token!");
        require((msg.value.mod(tokenPrice))==0, "Watch the token price, only whole tokens can be bought!");
        uint tokens = msg.value.div(tokenPrice);
        require(tokens <= maxUsedTokens, "Not enough tokens available!");
        tokenLogic.mint(msg.sender, tokens);
        tokens_of_voters[msg.sender] += tokens;
        maxUsedTokens -= tokens;
    }

    function sellTokens(uint nrTokens) participantRegistered public payable
    {
        require(tokens_of_voters[msg.sender] >= nrTokens, "You don't own so many tokens!"); 
        tokenLogic.burn(msg.sender, nrTokens);
        address payable addr = payable(msg.sender);
        addr.transfer(nrTokens.mul(tokenPrice));       
    }

    function getERC20Voting() external view returns(VotingToken)
    {
        return tokenLogic;
    }

    function getPendingProposals() external view votingOpen returns (uint[] memory  pending_proposals){

        // Counts number of pending proposals
        uint number_of_pending_proposals = 0;
        for(uint i = 0; i < proposals.length; i++){
            Proposal storage proposal = proposals[i];
            if(!proposal.is_cancelled && !proposal.is_approved && proposal.budget != 0){
                number_of_pending_proposals++;
            }
        }

        // Gets pending proposals
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

        // Counts number of approved proposals
        uint number_of_approved_proposals = 0;
        for(uint i = 0; i < proposals.length; i++){
            Proposal storage proposal = proposals[i];
            if(proposal.is_approved && proposal.budget != 0){
                number_of_approved_proposals++;
            }
        }


        // Gets approved proposals
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

        // Counts number of signaling proposals
        uint number_of_signaling_proposals = 0;
        for(uint i = 0; i < proposals.length; i++){
            Proposal storage proposal = proposals[i];
            if(proposal.budget == 0){
                number_of_signaling_proposals++;
            }
        }


        // Gets signaling proposals
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
            voters_of_proposals[proposalId].push(payable(msg.sender));
        }


        // Only executes financial proposals
        if(proposal.budget != 0){
            _checkAndExecuteProposal(proposalId);  
        }
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
    
    function _checkAndExecuteProposal(uint proposal_id) internal {
        Proposal storage proposal = proposals[proposal_id];
        if(proposal.budget > total_budget + (proposal.votes * tokenPrice)){
            return; // Doesn't meet required condition
        }

        // We multiply by 10 and by total_budget to avoid decimals
        uint threshold = (2 + (10 * proposal.budget)) * total_participants + (proposals.length * 10 * total_budget);
        uint total_votes = proposal.votes * 10 * total_budget;
        if(total_votes <= threshold){
            return; // Doesn't meet required condition
        }


        // Executes proposal
        IExecutableProposal executable_proposal = IExecutableProposal(proposal.executable_proposal_address);
        executable_proposal.executeProposal{value: proposal.budget, gas: 100000}(proposal_id);
        proposal.is_approved = true;

        address payable[] storage voters_of_proposal = voters_of_proposals[proposal_id];
        
        uint wei_for_owner = 0;


        // Returns remaining wei to owner
        for(uint i = 0; i < voters_of_proposal.length; i++){
            uint votes = votes_per_user_per_proposal[proposal_id][voters_of_proposal[i]];
            tokenLogic.burn(voters_of_proposal[i], votes**2);
            wei_for_owner += (votes**2)*tokenPrice;
        }

        total_budget = total_budget + wei_for_owner - proposal.budget;
    }

    function closeVoting() external onlyOwner{
        uint gas_per_iter = gas_per_iteration;
        bool first_time = gas_per_iter == 0;

        is_open = false;
        for(uint i = close_voting_i; i < proposals.length; i++)
        {
            Proposal storage proposal = proposals[i];


            if(proposal.is_approved == false)
            {
                if(first_time){
                    gas_per_iter = gasleft();
                }
                address payable[] storage voters_of_proposal = voters_of_proposals[i];
                mapping(address => uint256) storage votes_per_user = votes_per_user_per_proposal[i];
               for(uint j= close_voting_j; j<voters_of_proposal.length; j++)
                {
                    if(!first_time && (gasleft() < (3*gas_per_iter)))
                    {
                        close_voting_i = i;
                        close_voting_j = j;
                        return;          
                    }

                    if(votes_per_user[voters_of_proposal[j]]>0)
                    {
                        uint aux = votes_per_user[voters_of_proposal[j]];
                        votes_per_user[voters_of_proposal[j]] = 0;
                        address payable addr = payable(voters_of_proposal[j]);
                        addr.transfer((aux**2)*tokenPrice);
                    }
                    if(first_time){
                        first_time = false;
                        gas_per_iter -= gasleft();
                        gas_per_iteration = gas_per_iter;
                    }
                }

                // Executes every signaling proposal
                if(proposal.budget == 0){
                    IExecutableProposal executable_proposal = IExecutableProposal(proposal.executable_proposal_address);
                    executable_proposal.executeProposal{value: proposal.budget, gas: 100000}(i);
                }
            }
            delete proposals[i];
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
        require(ERC20.totalSupply() + amount <= _cap, "ERC20C: cap exceeded");
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

contract TestContract is IExecutableProposal
{ 
    event Pay(address sender, uint proposalId, uint value);
    
    function executeProposal(uint proposalId) override external payable
    {
        emit Pay(msg.sender, proposalId, msg.value);
    }
}


