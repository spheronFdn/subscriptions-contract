// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { BigNumber } = require("@ethersproject/bignumber");
const { ethers } = require("hardhat");
const hre = require("hardhat");
// const amount = ethers.BigNumber.from("100").mul(
//   ethers.BigNumber.from(10).pow(18)
// );
// const amount2 = ethers.BigNumber.from("110").mul(
//   ethers.BigNumber.from(10).pow(18)
// );
// const amount3 = ethers.BigNumber.from("120").mul(
//   ethers.BigNumber.from(10).pow(18)
// );
const discountSlabs = [];
const discountPercents = [];
const argoTestToken = "0xF7ec286A19CE6fe80c6A0d5CEb9528d9a87c9557";
// const usdcTest = "0xE163A5689Dc303f5A7AFdbbb050432Fb5a8E7174";
const escrow = "0xF7ec286A19CE6fe80c6A0d5CEb9528d9a87c9557";
// let argoPriceFeed = "0x987aeea14c3638766ef05f66e64f7ea38ddc8dcd";
// const argoFeedSymbol = "ARGO/USD";
// const usdcFeedSymbol = "USDC/USD";
// const usdcFeedAddress = "0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0";
const params = [
  "PACKAGE_PRO",
  "PACKAGE_STARTER",
  "BONUS_BANDWIDTH",
  "BONUS_BUILD_EXECUTION",
  "BONUS_CONCURRENT_BUILD",
  "BONUS_STORAGE",
  "BONUS_DEPLOYMENT_PER_DAY",
  "BONUS_DOMAIN_LIMIT",
  "BONS_HNS_DOMAIN_LIMIT",
  "BONUS_ENS_DOMAIN_LIMIT",
  "BONUS_ENVIRONMENTS",
];
const getConvertedPrice = (price) => {
  return ethers.utils.parseEther(price.toString());
};
const prices = [
  getConvertedPrice(18),
  getConvertedPrice(0),
  getConvertedPrice(0.5),
  getConvertedPrice(0.0002),
  getConvertedPrice(50),
  getConvertedPrice(0.1),
  getConvertedPrice(0.01),
  getConvertedPrice(0.2),
  getConvertedPrice(0.2),
  getConvertedPrice(0.2),
  getConvertedPrice(5),
];
// const priceFeedPrecisions = [8, 8];
// const priceFeedAddresses = [argoPriceFeed, usdcFeedAddress];
// const priceFeedSymbols = [argoFeedSymbol, usdcFeedSymbol];
// const isChainlink = [false, true];
// const tokenDecimals = [18, 6];
// const tokenAddresses = [argoTestToken, usdcTest];
const priceFeedSymbols = ["WETH/USD", "WMATIC/USD", "USDT/USD", "DAI/USD"];
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
  // console.log(prices)
  //   const Data = await hre.ethers.getContractFactory("SubscriptionData");
  const constructorArgs = [
    params,
    prices,
    escrow,
    discountSlabs,
    discountPercents,
    argoTestToken,
  ];
  //   const data = await Data.deploy(...constructorArgs);
  //   await data.deployed();
  await hre.run("verify:verify", {
    address: "0x889124cD6Ef997fc7a2cE9ed9149866337F22f66",
    constructorArguments: constructorArgs,
  });
  console.log("Payments contract deployed to:", data.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
