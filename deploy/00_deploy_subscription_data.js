const { ethers } = require("hardhat");
module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy} = deployments;
    console.log(deploy)
    const {deployer} = await getNamedAccounts();
    const discountSlabs = [];
    const discountPercents = [];
    const spheTestToken = "0xF7ec286A19CE6fe80c6A0d5CEb9528d9a87c9557"; // set Project Native Token
    const escrow = "0xF7ec286A19CE6fe80c6A0d5CEb9528d9a87c9557"; // set Escrow address if any
    // List of Subscription Item for your project
    const params = [
        "PACKAGE_PRO_FIRST",
        "PACKAGE_PRO",
        "PACKAGE_STARTER",
      ];
      const getConvertedPrice = (price) => {
        return ethers.utils.parseEther(price.toString());
      };
      const prices = [
        getConvertedPrice(20),
        getConvertedPrice(15),
        getConvertedPrice(0),
      ];
    await deploy('SubscriptionData', {
      from: deployer,
      args: [params, prices, escrow, discountSlabs, discountPercents, spheTestToken],
      log: true,
    });
  };