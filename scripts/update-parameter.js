// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

const address = "0x889124cD6Ef997fc7a2cE9ed9149866337F22f66";
const managers = ["0xbae1b2c5ecd83c00bad64d45492750b978214a61"];
const escrow = "0x97F5aE30eEdd5C3c531C97E41386618b1831Cb7b";

const tokenName = ["WETH", "WMATIC", "USDT", "DAI"];
const tokenAddresses = [
  "0xB20Ca4FD8C23B0ff8259EcDF6F3232A589562CdC",
  "0x960d7D3aD51CbFe74CF61a5c882C9020DF50a18d",
  "0x36fEe18b265FBf21A89AD63ea158F342a7C64abB",
  "0xf0728Bfe68B96Eb241603994de44aBC2412548bE",
];
const tokenDecimals = [18, 18, 6, 18];
const isChainlink = [true, true, true, true];
const priceFeedAddresses = [
  "0x0715A7794a1dc8e42615F059dD6e406A6594651A",
  "0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada",
  "0x92C09849638959196E976289418e5973CC96d645",
  "0x0FCAa9c899EC5A91eBc3D5Dd869De833b06fB046",
];
const priceFeedPrecisions = [8, 8, 8, 8];

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const Payments = await hre.ethers.getContractFactory("SubscriptionData");
  const payments = Payments.attach(address);
  const tx = await payments.addNewTokens(
    tokenName,
    tokenAddresses,
    tokenDecimals,
    isChainlink,
    priceFeedAddresses,
    priceFeedPrecisions
  );
  console.log("Tx hash:", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
