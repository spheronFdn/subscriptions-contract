// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

const data = "0x889124cD6Ef997fc7a2cE9ed9149866337F22f66";
async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const constructorArgs = [data];
  //   const Payments = await hre.ethers.getContractFactory("SubscriptionPayments");
  //   const payments = await Payments.deploy(...constructorArgs);
  //   await payments.deployed();
  await hre.run("verify:verify", {
    address: "0x2f2d259bB988F02Ce5f3e4200D669469204B5F48",
    constructorArguments: constructorArgs,
  });
  console.log("Payments contract deployed to:", payments.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
