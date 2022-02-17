// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { BigNumber } = require("@ethersproject/bignumber");
const hre = require("hardhat");
const amount = ethers.BigNumber.from("100").mul(ethers.BigNumber.from(10).pow(18))
const amount2 = ethers.BigNumber.from("110").mul(ethers.BigNumber.from(10).pow(18))
const amount3 = ethers.BigNumber.from("120").mul(ethers.BigNumber.from(10).pow(18))
const discountSlabs = [amount, amount2, amount3];
const discountPercents = [10, 15, 20];
const argoTestToken = "0x6794a9E5411f8f9B3E5Dc7457162728544A443E0"
const usdcTest = "0xE163A5689Dc303f5A7AFdbbb050432Fb5a8E7174"
const escrow = "0x97F5aE30eEdd5C3c531C97E41386618b1831Cb7b"
let argoPriceFeed = "0x987aeea14c3638766ef05f66e64f7ea38ddc8dcd"
const argoFeedSymbol = "ARGO/USD";
const usdcFeedSymbol = "USDC/USD"
const usdcFeedAddress = "0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0"
const params = ["PRICE_PER_DEPLOYMENT", "PRICE_PER_WEBHOOK", "PRICE_BUILDING_TIME"]
const prices = [BigNumber.from(10).pow(17), BigNumber.from(5).mul(BigNumber.from(10).pow(17)), BigNumber.from(10).pow(16)]
const priceFeedPrecisions = [8, 8]
const priceFeedAddresses = [argoPriceFeed, usdcFeedAddress];
const priceFeedSymbols = [argoFeedSymbol, usdcFeedSymbol];
const isChainlink = [false, true];
const tokenDecimals = [18, 6];
const tokenAddresses = [argoTestToken, usdcTest];
async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // We get the contract to deploy
    // console.log(prices)
    const Data = await hre.ethers.getContractFactory("SubscriptionData");
    const constructorArgs= [params, prices, escrow, discountSlabs, discountPercents, argoTestToken]
    const data = await Data.deploy(...constructorArgs);
    await data.deployed();
    await hre.run("verify:verify", {
        address: "0x15a0432dc080daa0865316233034ef9eb2d5b409",
        constructorArguments: constructorArgs,
      });
    const [signer] = await ethers.getSigners();
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
