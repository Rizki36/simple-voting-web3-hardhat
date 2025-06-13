// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleVotingWeb3
 * @dev A decentralized voting platform that allows proposal creation and voting
 * Pagination, filtering and sorting is handled client-side for gas efficiency
 */
contract SimpleVotingWeb3 is Ownable {
    uint256 private _proposalIds;

    enum ProposalStatus {
        Active,
        Ended
    }

    struct Proposal {
        uint256 id;
        string title;
        string description;
        string[] options;
        uint256[] votes;
        uint256 totalVotes;
        uint256 endTime;
        address creator;
        ProposalStatus status;
    }

    // Mapping from proposal ID to Proposal
    mapping(uint256 => Proposal) public proposals;

    // Mapping from proposal ID to voter address to whether they voted
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // Mapping from proposal ID to voter address to their vote choice
    mapping(uint256 => mapping(address => uint256)) public voterChoice;

    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        string title,
        address creator,
        uint256 endTime
    );
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 option
    );
    event ProposalEnded(
        uint256 indexed proposalId,
        uint256 winningOption,
        uint256 winningVotes
    );

    // Modifiers
    modifier onlyActiveProposal(uint256 proposalId) {
        require(
            proposals[proposalId].status == ProposalStatus.Active,
            "Proposal is not active"
        );
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(
            proposalId > 0 && proposalId <= _proposalIds,
            "Proposal does not exist"
        );
        _;
    }

    modifier hasNotVotedYet(uint256 proposalId) {
        require(
            !hasVoted[proposalId][msg.sender],
            "Already voted on this proposal"
        );
        _;
    }

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Creates a new proposal
     * @param title The title of the proposal
     * @param description The description of the proposal
     * @param options Array of voting options
     * @param endTime The timestamp when the proposal ends
     */
    function createProposal(
        string memory title,
        string memory description,
        string[] memory options,
        uint256 endTime
    ) external onlyOwner returns (uint256) {
        require(options.length >= 2, "At least 2 options required");
        require(endTime > block.timestamp, "End time must be in the future");

        // Increment counter directly
        _proposalIds += 1;
        uint256 newProposalId = _proposalIds;

        uint256[] memory initialVotes = new uint256[](options.length);

        proposals[newProposalId] = Proposal({
            id: newProposalId,
            title: title,
            description: description,
            options: options,
            votes: initialVotes,
            totalVotes: 0,
            endTime: endTime,
            creator: msg.sender,
            status: ProposalStatus.Active
        });

        emit ProposalCreated(newProposalId, title, msg.sender, endTime);
        return newProposalId;
    }

    /**
     * @dev Allows a user to vote on a proposal
     * @param proposalId The ID of the proposal
     * @param optionIndex The index of the option to vote for
     */
    function vote(
        uint256 proposalId,
        uint256 optionIndex
    )
        external
        proposalExists(proposalId)
        onlyActiveProposal(proposalId)
        hasNotVotedYet(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];

        // Check if voting period has ended
        if (block.timestamp > proposal.endTime) {
            proposal.status = ProposalStatus.Ended;
            revert("Voting period has ended");
        }

        require(optionIndex < proposal.options.length, "Invalid option index");

        // Mark user as having voted
        hasVoted[proposalId][msg.sender] = true;
        voterChoice[proposalId][msg.sender] = optionIndex;

        // Update vote count
        proposal.votes[optionIndex]++;
        proposal.totalVotes++;

        emit Voted(proposalId, msg.sender, optionIndex);

        // Check if voting should end automatically due to time
        if (block.timestamp >= proposal.endTime) {
            _endProposal(proposalId);
        }
    }

    /**
     * @dev Manually ends a proposal
     * @param proposalId The ID of the proposal to end
     */
    function endProposal(
        uint256 proposalId
    )
        external
        onlyOwner
        proposalExists(proposalId)
        onlyActiveProposal(proposalId)
    {
        _endProposal(proposalId);
    }

    /**
     * @dev Internal function to end a proposal and determine the winning option
     * @param proposalId The ID of the proposal to end
     */
    function _endProposal(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        proposal.status = ProposalStatus.Ended;

        uint256 winningOption = 0;
        uint256 winningVotes = 0;

        for (uint256 i = 0; i < proposal.votes.length; i++) {
            if (proposal.votes[i] > winningVotes) {
                winningOption = i;
                winningVotes = proposal.votes[i];
            }
        }

        emit ProposalEnded(proposalId, winningOption, winningVotes);
    }

    /**
     * @dev Gets the results of a proposal
     * @param proposalId The ID of the proposal
     * @return options The array of option names
     * @return votes The array of vote counts per option
     * @return totalVotes The total number of votes cast
     * @return status The status of the proposal
     */
    function getProposalResults(
        uint256 proposalId
    )
        external
        view
        proposalExists(proposalId)
        returns (
            string[] memory options,
            uint256[] memory votes,
            uint256 totalVotes,
            ProposalStatus status
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.options,
            proposal.votes,
            proposal.totalVotes,
            proposal.status
        );
    }

    /**
     * @dev Gets details about a proposal
     * @param proposalId The ID of the proposal
     */
    function getProposal(
        uint256 proposalId
    )
        external
        view
        proposalExists(proposalId)
        returns (
            uint256 id,
            string memory title,
            string memory description,
            uint256 endTime,
            address creator,
            ProposalStatus status,
            uint256 totalVotes
        )
    {
        Proposal storage proposal = proposals[proposalId];

        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.endTime,
            proposal.creator,
            proposal.status,
            proposal.totalVotes
        );
    }

    /**
     * @dev Gets active proposals with pagination
     */
    function getActiveProposalIds() external view returns (uint256[] memory) {
        uint256 totalProposals = _proposalIds;
        uint256[] memory activeIds = new uint256[](totalProposals); // Max possible size
        uint256 activeCount = 0;

        // Collect all active proposal IDs
        for (uint256 i = 1; i <= totalProposals; i++) {
            if (proposals[i].status == ProposalStatus.Active) {
                activeIds[activeCount] = i;
                activeCount++;
            }
        }

        // Create correctly sized result array
        uint256[] memory result = new uint256[](activeCount);
        for (uint256 i = 0; i < activeCount; i++) {
            result[i] = activeIds[i];
        }

        return result;
    }

    /**
     * @dev Gets voter information for a proposal
     * @param proposalId The ID of the proposal
     * @param voter The address to check
     */
    function getVoterInfo(
        uint256 proposalId,
        address voter
    )
        external
        view
        proposalExists(proposalId)
        returns (bool voted, uint256 chosenOption)
    {
        voted = hasVoted[proposalId][voter];
        chosenOption = voted ? voterChoice[proposalId][voter] : 0;
    }

    /**
     * @dev Gets the total number of proposals created
     */
    function getProposalCount() external view returns (uint256) {
        return _proposalIds;
    }

    /**
     * @dev Gets all proposal IDs (more gas efficient for client-side filtering)
     */
    function getAllProposalIds() external view returns (uint256[] memory) {
        uint256 count = _proposalIds;
        uint256[] memory ids = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            ids[i] = i + 1; // IDs start at 1
        }

        return ids;
    }

    /**
     * @dev Gets proposal status by ID (useful for client-side filtering)
     * @param proposalId The ID of the proposal
     */
    function getProposalStatus(
        uint256 proposalId
    ) external view proposalExists(proposalId) returns (ProposalStatus) {
        return proposals[proposalId].status;
    }

    /**
     * @dev Gets basic proposal info in batches to reduce RPC calls
     * @param proposalIds Array of proposal IDs to fetch
     */
    function getProposalsBasicInfo(
        uint256[] calldata proposalIds
    )
        external
        view
        returns (
            uint256[] memory ids,
            string[] memory titles,
            ProposalStatus[] memory statuses,
            uint256[] memory endTimes,
            uint256[] memory totalVotes
        )
    {
        // Only create arrays for valid proposal IDs
        uint256 validCount = 0;
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (proposalIds[i] > 0 && proposalIds[i] <= _proposalIds) {
                validCount++;
            }
        }

        // Initialize arrays with correct size
        ids = new uint256[](validCount);
        titles = new string[](validCount);
        statuses = new ProposalStatus[](validCount);
        endTimes = new uint256[](validCount);
        totalVotes = new uint256[](validCount);

        // Fill arrays with valid proposals only
        uint256 index = 0;
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (proposalIds[i] > 0 && proposalIds[i] <= _proposalIds) {
                Proposal storage proposal = proposals[proposalIds[i]];
                ids[index] = proposal.id;
                titles[index] = proposal.title;
                statuses[index] = proposal.status;
                endTimes[index] = proposal.endTime;
                totalVotes[index] = proposal.totalVotes;
                index++;
            }
        }

        return (ids, titles, statuses, endTimes, totalVotes);
    }

    /**
     * @dev Gets full proposal details including options and votes
     * @param proposalId The ID of the proposal
     */
    function getFullProposal(
        uint256 proposalId
    )
        external
        view
        proposalExists(proposalId)
        returns (
            uint256 id,
            string memory title,
            string memory description,
            string[] memory options,
            uint256[] memory votes,
            uint256 endTime,
            address creator,
            ProposalStatus status,
            uint256 totalVotes
        )
    {
        Proposal storage proposal = proposals[proposalId];

        // Update status based on time
        ProposalStatus currentStatus = proposal.status;
        if (
            currentStatus == ProposalStatus.Active &&
            block.timestamp > proposal.endTime
        ) {
            currentStatus = ProposalStatus.Ended;
        }

        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.options,
            proposal.votes,
            proposal.endTime,
            proposal.creator,
            currentStatus,
            proposal.totalVotes
        );
    }
}
