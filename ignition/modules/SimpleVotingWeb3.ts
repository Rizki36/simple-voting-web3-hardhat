import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const SimpleVotingWeb3Module = buildModule("SimpleVotingWeb3Module", (m) => {
    // Deploy the SimpleVotingWeb3 contract
    const simpleVotingWeb3 = m.contract("SimpleVotingWeb3");

    // You can add example proposal creation for testing
    // Note: This will only run if specified in deployment plan
    m.call(simpleVotingWeb3, "createProposal", [
        "Example Proposal",
        "This is an example proposal to test the contract functionality.",
        ["Approve", "Reject", "Abstain"],
        // Set end time to 7 days from deployment (in seconds)
        Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60,
    ], { id: "createExampleProposal" });

    // Return the deployed contract
    return { simpleVotingWeb3 };
});

export default SimpleVotingWeb3Module;