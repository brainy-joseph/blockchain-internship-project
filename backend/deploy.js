const hre = require("hardhat");

async function main() {
  console.log("Deploying NFTTicket contract...");
  
  const NFTTicket = await hre.ethers.getContractFactory("NFTTicket");
  const nftTicket = await NFTTicket.deploy();
  
  await nftTicket.waitForDeployment();
  
  const address = await nftTicket.getAddress();
  console.log("NFTTicket deployed to:", address);
  console.log("");
  console.log("Copy this address into your frontend.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
