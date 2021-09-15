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
const escrow = "0x97F5aE30eEdd5C3c531C97E41386618b1831Cb7b"
let priceFeed = "0x987aeea14c3638766ef05f66e64f7ea38ddc8dcd"
const priceFeedSymbol = "ARGO/USD";
const params = ["PRICE_PER_DEPLOYMENT", "PRICE_PER_WEBHOOK", "PRICE_BUILDING_TIME"]
const prices = [BigNumber.from(10).pow(17), BigNumber.from(5).mul(BigNumber.from(10).pow(17)), BigNumber.from(10).pow(16)]

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // We get the contract to deploy
    console.log(prices)
    const Data = await hre.ethers.getContractFactory("SubscriptionData");
    const data = await Data.deploy(params, prices, argoTestToken, escrow, discountSlabs, discountPercents, priceFeed, argoTestToken, priceFeedSymbol);
    await data.deployed();

    console.log("Greeter deployed to:", data.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });