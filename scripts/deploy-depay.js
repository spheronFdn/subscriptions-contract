// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const timeStampGap = 86400;
const treasury = "0x562937835cdD5C92F54B94Df658Fd3b50A68ecD5";
const company = "0x562937835cdD5C92F54B94Df658Fd3b50A68ecD5";
const data = "0x75427d17bA81A4f960029C85aEba22809f3E10A7";
const forwarder = "0x69FB8Dca8067A5D38703b9e8b39cf2D51473E4b4"

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const constructorArgs = [timeStampGap, treasury, company, data, forwarder];
  // const DePayments = await hre.ethers.getContractFactory("SubscriptionDePay");
  // const dePayments = await DePayments.deploy(...constructorArgs);
  // await dePayments.deployed();
  await hre.run("verify:verify", {
    address: "0x7E80c85d2F689b4C457e53a1865A8bDb92Ba858d",
    constructorArguments: constructorArgs,
  });
  // console.log("DePayments contract deployed to:", dePayments.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
