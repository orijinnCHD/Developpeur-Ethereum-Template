 // SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

/*Voting system
    
    This contract allows for decentralized voting
    you can create a whitelist to access the voting services (proposal and vote).

    The proposal with the most votes wins the election.

    we added differenst verification:
    -check if you have already suggest this proposal
    -check if we have tie vote and revert if true.

    Created by charles DUTER

*/

contract Voting is Ownable{

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    WorkflowStatus private status;
    
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    Proposal[] private proposals;
    address[] private addressVoters;
    mapping (address => Voter) private voters;  
    
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);


//----------------------constructor -----------------------------//

    constructor()Ownable(){}

//-------------------modifier-------------------------------------//


    /* onlyWhitelisters : 
        -- check this voter can participate and view information in voting session.
    */
    modifier onlyWhitelisters(){
        
        require( voters[msg.sender].isRegistered, "sorry, only Whitelisters can participate and view information" );
        _;

    }


    /* onlyStatus : 
        -- check access voter for this WorkflowStatus.
    */
    modifier onlyStatus( WorkflowStatus _status ){
        
        require(status == _status, "you can't access ! waiting admin change workflow status" );
        _;
    }


    /* onlyProposalsCreated : 
        -- check if there is one proposal minimum.
        -- security : admin mislead in workflowStatus (something vote with no proposal).
    */
    modifier onlyProposalsCreated(){
        
        require(proposals.length > 0 , "no proposals are suggested");
        _;
    }

//------------------- function----------------------------------//


    /* setStatus : 
        -- admin can control workflowStatus.
    */
    function setStatus( WorkflowStatus _status ) public onlyOwner{
        
        emit WorkflowStatusChange( status , _status );
        status = _status;
        
    }


    /* getStatus : 
        -- access : admin
    */
    function getStatus() public onlyOwner view returns( WorkflowStatus ){

        return status;

    }


    /* whitelist : 
        -- access : admin (set RegisteringVoters , set address new voters ) 
        -- voters[ _address ] : register new voters.
        -- VoterRegistered : log address voter registered ( event )
        ** Bonus addressVoters[] : register Voters address for reset "voters"
    */
    function Whitelist( address _address ) public onlyOwner onlyStatus(  WorkflowStatus.RegisteringVoters ){
        
        require( _address != address(0),"you can not use this address(0x00)" );
        require( !voters[ _address ].isRegistered , "your address is already registered" );
        voters[ _address ] = Voter( true, false, 0 );
        addressVoters.push( _address );
        emit VoterRegistered( _address );
    }


    /* setYourProposal : 
        -- access : admin ( set ProposalsRegistrationStarted ) , whitelisters ( exclusive ) 
        -- proposals[]: register the proposal voter, he can create several proposals
        ** Bonus checkSameDescription() : check if voter propose same description
    */
    function setYourProposal( string calldata _description ) public onlyWhitelisters onlyStatus(  WorkflowStatus.ProposalsRegistrationStarted ) {
        
        require( bytes(_description).length > 0  ," your must write a description proposal" );
        require( !checkSameDescription(  _description ) , " this description is already suggest, create another description " ); // bonus : check same description
        proposals.push( Proposal( _description, 0 ));
        emit ProposalRegistered( proposals.length -1 );
    }


    /** bonus: checkSameDescription : 
        -- access : smartContract
        -- check same proposition in function "setYourProposal"
        -- true : find same description proposal
        -- false : doesn't find;
    */
    function checkSameDescription( string calldata _description ) internal view returns( bool ){

        bool isVerified = false;
        for(uint i = 0 ; i < proposals.length; i++){
            if( isEqual( proposals[i].description , _description ) )
                isVerified = true;
            else
                isVerified = false;
        }
        return isVerified;

    }


    /** bonus: isEqual : 
        -- access : smartContract
        -- computation check first element by second element"
    */
    function isEqual( string memory _firstElement ,string memory _secondElement ) internal pure returns( bool ){

        if(keccak256(abi.encodePacked( _firstElement)) == keccak256(abi.encodePacked( _secondElement)))
            return true;
        else
            return false;
        
    }


    /* setYourVote : 
        -- access : admin ( set ProposalsRegistrationStarted ) , whitelisters ( exclusive ) , check minimum one proposal
        -- voters[]: register the vote id voter, valid hasVoted 
        -- proposals[] : increase voteCount 
    */
    function setYourVote( uint _votedProposalId )public onlyWhitelisters onlyProposalsCreated onlyStatus( WorkflowStatus.VotingSessionStarted ){

        require(_votedProposalId < proposals.length, "no proposal has this ID" );
        require(!voters[msg.sender].hasVoted,"you cannot voted several times");
        voters[ msg.sender ].votedProposalId = _votedProposalId;
        voters[ msg.sender ].hasVoted = true;
        proposals[ _votedProposalId ].voteCount++; 
        emit Voted ( msg.sender , _votedProposalId );
        
    }


    /* getWinner : 
        -- access : admin ( set VotesTallied ) , whitelisters ( exclusive ) , check minimum one proposal.
        -- winningProposalId: id winner.
        ** bonus isEqualVote : check if winner is equal with anothers proposals: 
        ------- True: revert vote( optmin ), and waiting admin resetTheVote().
        ------- false: returns the winner.
    */
    function getWinner()public onlyStatus( WorkflowStatus.VotesTallied ) onlyWhitelisters onlyProposalsCreated view returns( string memory  ){

        uint winningProposalId = findTheWinner();
        bool isEqualVote = checkEqualVote( winningProposalId );
        if( isEqualVote )
            revert("there is equality, waiting admin 'reset The Vote' and you can vote again");
        else
            return proposals[winningProposalId].description;

    }


    /* findTheWinner : 
        -- access : smartcontract
    */
    function findTheWinner()internal view returns( uint ){

        uint winner;
        for(uint i = 0 ; i < proposals.length ; i++){
            if(proposals[i].voteCount > winner )
                winner = i;    
        }
        return winner;
    }


    /* bonus checkEqualVote : 
        -- access : smartcontract( this )
        -- winningProposalId != i : doesn't check himself 
    */
    function checkEqualVote(uint _winningProposalId )internal view returns(bool){

        bool equal;
        for(uint i = 0 ; i < proposals.length ; i++){
            if(_winningProposalId != i && proposals[i].voteCount == proposals[_winningProposalId].voteCount ){
                equal = true;
            } 
        }
        return equal;

    }


    /* bonus ResetTheVote : 
        -- access : admin
        -- reset variable voter( votedId , hasVoted ) ,proposal[](votedCount)
        -- status : come back to VotingSessionStarted
    */
    function ResetTheVote() public onlyOwner {

        resetVoters( true , false , 0 );
        for(uint i = 0 ; i < proposals.length; i++){
            proposals[i].voteCount = 0;
        }
        emit WorkflowStatusChange( WorkflowStatus.VotesTallied , WorkflowStatus.VotingSessionStarted );
        status = WorkflowStatus.VotingSessionStarted;
        
    }


    function resetVoters(bool _register , bool _voted , uint _votedcount ) internal{
        
        for(uint i = 0 ; i < addressVoters.length ; i++ ){
            voters[ addressVoters[i] ] = Voter( _register, _voted, _votedcount );
        }
        
    }


    /*ResetAll :
        -- acces : admin
        --reset all voting session
    */
    function ResetAll() public onlyOwner{

        resetVoters( false , false , 0 );
        delete proposals;
        delete addressVoters;
        emit WorkflowStatusChange( status , WorkflowStatus.RegisteringVoters );
        status = WorkflowStatus.RegisteringVoters;

    }

    //---------------------visibility data by whitelisters -------------------------------------//
    
    function getProposals()public onlyWhitelisters view returns (Proposal[] memory){
        return proposals;
    }


    function getAddressVoters() public onlyWhitelisters view returns( address[] memory ){
        return addressVoters;
    }


    function getVotersByAddress(address _address )public onlyWhitelisters view returns (Voter memory ){
        require( _address != address(0),"you cannot use this address(0x00)" );
        return voters[_address];
    }

}
