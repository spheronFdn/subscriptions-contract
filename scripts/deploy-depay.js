// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const treasury = "0x562937835cdD5C92F54B94Df658Fd3b50A68ecD5";
const company = "0x3ae68d8eFB25C137aBd52F16f3fF3067856aa175";
const data = "0xa7336a9e1adb36b31bf9bbe8b1fd738e64d9b8db";
const forwarder = "0x67454E169d613a8e9BA6b06af2D267696EAaAf41"

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const constructorArgs = [treasury, company, data, forwarder];
  const DePayments = await hre.ethers.getContractFactory("SubscriptionDePay");
  const dePayments = await DePayments.deploy(...constructorArgs);
  await dePayments.deployed();
  await hre.run("verify:verify", {
    address: "0x9C0a16a41d2b0fFc14e6f20Da1368b1FD93bD7e5",
    constructorArguments: constructorArgs,
  });
  console.log("DePayments contract deployed to:", dePayments.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
