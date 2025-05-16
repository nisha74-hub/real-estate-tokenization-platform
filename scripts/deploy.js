const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying RealEstateToken contract...");

  // Get the contract factory
  const RealEstateToken = await ethers.getContractFactory("RealEstateToken");
  
  // Deploy the contract
  const realEstateToken = await RealEstateToken.deploy();
  
  // Wait for deployment to finish
  await realEstateToken.waitForDeployment();
  
  // Get the deployed contract address
  const realEstateTokenAddress = await realEstateToken.getAddress();
  
  console.log("RealEstateToken deployed to:", realEstateTokenAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
