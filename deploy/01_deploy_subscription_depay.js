const { ethers } = require("hardhat");
const timeStampGap = 86400;
const treasury = "0x562937835cdD5C92F54B94Df658Fd3b50A68ecD5";
const company = "0x562937835cdD5C92F54B94Df658Fd3b50A68ecD5";
const forwarder = "0x69FB8Dca8067A5D38703b9e8b39cf2D51473E4b4"
module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy} = deployments;
    console.log(deploy)
    const {deployer} = await getNamedAccounts();
    const data = await ethers.getContract('SubscriptionData')
      
    await deploy('SubscriptionDePay', {
      from: deployer,
      args: [timeStampGap, treasury, company, data.address, forwarder],
      log: true,
    });
};