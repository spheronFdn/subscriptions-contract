require("@nomiclabs/hardhat-etherscan");
require("solidity-coverage");
require("@nomiclabs/hardhat-waffle");
const dotenv = require("dotenv");
dotenv.config();
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: {
        version: "0.8.16",
    }, 
    etherscan: {
        // Your API key for Etherscan
        // Obtain one at https://etherscan.io/
        apiKey: "CCZ9FSNT1PRX74XPHHY6HVBWVZJKFFZ3RE"
    },
    networks: {

        hardhat: {
            forking: {
                url: "https://polygon-mumbai.g.alchemy.com/v2/PCPWJQnqrgI6RQHx64dGKXZGmqEYOHwk",
                blockNumber: 18908757
            },
            allowUnlimitedContractSize: true,
        },
        localhost: {
            url: "http://localhost:8545",
            /*
              notice no mnemonic here? it will just use account 0 of the buidler node to deploy
              (you can put in a mnemonic here to set the deployer locally)
            */
            throwOnTransactionFailures: true,
            throwOnCallFailures: true,
            allowUnlimitedContractSize: true,
            blockGasLimit: 0x1fffffffffffff,

        },
        goerli: {
            url: `https://goerli.infura.io/v3/8b8d0c60bfab43bc8725df20fc660d15`, // <---- YOUR INFURA ID! (or it won't work)
            accounts: {
                mnemonic: 'company loud estate century olive gun tribe pulse bread play addict amount',
            },
        },
        rinkeby: {
            url: `https://rinkeby.infura.io/v3/0e4ce57afbd04131b6842f08265b4d4b`, // <---- YOUR INFURA ID! (or it won't work)
            accounts: {
                mnemonic: 'company loud estate century olive gun tribe pulse bread play addict amount',
            },
        },
        kovan: {
            url: `https://kovan.infura.io/v3/0e4ce57afbd04131b6842f08265b4d4b`, // <---- YOUR INFURA ID! (or it won't work)
            accounts: {
                mnemonic: 'company loud estate century olive gun tribe pulse bread play addict amount',
            },
        },
        arbitrum: {
            url: 'https://rinkeby.arbitrum.io/rpc',
            accounts: [process.env.ARBI_PRIVATE_KEY],
        },
        mumbai: {
            url: 'https://rpc-mumbai.maticvigil.com/',
            accounts: [process.env.MUMBAI_PRIVATE_KEY],
        },

    },

};