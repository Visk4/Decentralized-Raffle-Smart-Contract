🎟️ Decentralized Raffle Smart Contract

A secure, automated, and provably fair lottery system built with Solidity and the Foundry development framework. This project utilizes Chainlink VRF for decentralized randomness and Chainlink Automation for trustless execution.

🌟 Key Features

Provably Fair: Uses Chainlink VRF (Verifiable Random Function) v2.5 to ensure winner selection is tamper-proof and verifiable on-chain.

Fully Automated: Integrated with Chainlink Automation to trigger raffle draws based on time intervals without manual intervention.

Gas Optimized: Uses custom errors instead of strings to save gas and efficient state management patterns.

Robust Testing: Comprehensive test suite including unit tests, integration tests, and forked-network testing.

Dynamic Configuration: Easily deployable across different networks (Sepolia, Mainnet, etc.) using automated scripts.

🛠️ Tech Stack

Smart Contract Language: Solidity 0.8.19+

Development Framework: Foundry

Oracles: Chainlink VRF & Chainlink Automation

📋 Prerequisites

Ensure you have the following installed:

Git

Foundry

🔧 Installation & Setup

Clone the repository:

git clone [https://github.com/Visk4/Decentralized-Raffle-Smart-Contract.git](https://github.com/Visk4/Decentralized-Raffle-Smart-Contract.git)
cd Decentralized-Raffle-Smart-Contract


Install dependencies:

forge install


Build the project:

forge build


🧪 Testing

Run the full test suite to ensure everything is working correctly:

# Run all tests
forge test

# Run tests with high verbosity (useful for debugging)
forge test -vvv

# Check test coverage
forge coverage


🚀 Deployment

1. Configure Environment

Create a .env file in the root directory:

PRIVATE_KEY=your_private_key
SEPOLIA_RPC_URL=your_rpc_url
ETHERSCAN_API_KEY=your_etherscan_api_key


2. Deploy to Sepolia Testnet

source .env
forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv


📖 How It Works

Entrance: Users participate by calling enterRaffle and paying the entranceFee.

Maintenance: Chainlink Automation periodically calls checkUpkeep to see if the raffle is ready (interval passed, has players, has ETH).

Trigger: If checkUpkeep returns true, performUpkeep is executed, which requests a random number from Chainlink VRF.

Resolution: Chainlink VRF returns the randomness via fulfillRandomWords. The contract picks a winner using a modulo operation, transfers the prize pool, and resets for the next round.

📁 Project Structure

.
├── src/                # Smart Contract source files
├── script/             # Deployment and interaction scripts
├── test/               # Unit and integration tests
├── lib/                # External libraries (Chainlink, Forge-std)
└── foundry.toml        # Foundry configuration


📄 License

This project is licensed under the MIT License.
