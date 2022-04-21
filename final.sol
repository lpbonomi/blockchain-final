// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract QuadraticVoting is IERC20{
    address owner;
    bool is_open;
    uint initial_budget;
    mapping (address => uint) tokens_of_voters;
    Proposal[] proposals;

    struct Proposal {
        address owner;
        string title;
        string description;
        uint budget;
        address executable_proposal_address;
        bool is_approved;
        bool is_cancelled;
        mapping(address => uint) votes_per_user;
    }


    constructor(){
        owner = msg.sender;
    }



    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can call this function.");
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


    // Pregunta como se agrega plata ??
    function addParticipant() external payable {
        require(tokens_of_voters[msg.sender] == 0, "Participant already registered.");
        //TODO 
        //  Participants must transfer Ether when registering to buy tokens (at least one token)
        //   that will be used for casting their votes.
        
        //TODO buy tokens with msg.value
    }
    
    function addProposal(string memory title, string memory description, uint budget, address executable_proposal_address) external votingOpen returns (uint proposal_id  ){
        require(bytes(title).length > 0, "Title can't be empty");
        require(bytes(description).length > 0, "Title can't be empty");
        //TODO verificar address del contrato existe?
        //TODO require onlyParticipant
        //proposals.push(Proposal(msg.sender, title, description, budget, executable_proposal_address, false, false, 
        // TODO como hacer con el mapping
        //));
        return proposals.length - 1;
    }

    function cancelProposal(uint proposal_id) external votingOpen onlyProposalOwner(proposal_id){
            require(!proposals[proposal_id].is_approved, "Approved proposals can't be cancelled.");
            require(!proposals[proposal_id].is_cancelled, "Proposal has been cancelled already.");
            //TODO return tokens
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

    function withdrawFromProposal(uint amount_of_votes, uint proposal_id) external{
        Proposal storage proposal = proposals[proposal_id];
        require(!proposal.is_approved, "The proposal has already been approved");
            // TODO require tokens match votes available
            //TODO return tokens to participant
    }

    // funciton _checkAndExecuteProposal() internal {
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
    
       /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value)

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

