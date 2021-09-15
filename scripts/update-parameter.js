// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

const address = "0x66f2C4e2fc02C69C5AC5206f9AE46e2B54195660"
const managers = ["0xbae1b2c5ecd83c00bad64d45492750b978214a61"]
const escrow = "0x97F5aE30eEdd5C3c531C97E41386618b1831Cb7b"
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
    const tx = await payments.updateEscrow(escrow);
    console.log("Greeter deployed to:", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });