require("@nomiclabs/hardhat-ethers")
require("@nomiclabs/hardhat-etherscan");
require("solidity-coverage");
require("@nomiclabs/hardhat-waffle");
require('hardhat-deploy');
const dotenv = require("dotenv");
dotenv.config();

module.exports = {
    solidity: {
        version: "0.8.19",
    }, 
    settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    etherscan: {
        // Your API key for Etherscan
        // Obtain one at https://etherscan.io/
        apiKey: "CCZ9FSNT1PRX74XPHHY6HVBWVZJKFFZ3RE"
    },
    namedAccounts: {
        deployer: {
            default: 0, // here this will by default take the first account as deployer
            1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
            4: '[process.env.DEPLOYER_ADDRESS]', // but for rinkeby it will be a specific address
            97	: '[process.env.DEPLOYER_ADDRESS]', // but for bnb testnet it will be a specific address
            "goerli": '[process.env.DEPLOYER_ADDRESS]', //it can also specify a specific netwotk name (specified in hardhat.config.js)
        },
        feeCollector:{
            default: 1, // here this will by default take the second account as feeCollector (so in the test this will be a different account than the deployer)
            1: '[process.env.DEPLOYER_ADDRESS]', // on the mainnet the feeCollector could be a multi sig
            4: '[process.env.DEPLOYER_ADDRESS]', // on rinkeby it could be another account
        }
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
            url: 'https://goerli.blockpi.network/v1/rpc/public',
            accounts: [process.env.PRIVATE_KEY],
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
            accounts: [process.env.PRIVATE_KEY],
        },
        mumbai: {
            url: 'https://rpc.ankr.com/polygon_mumbai',
            accounts: [process.env.PRIVATE_KEY],
        },
        bnb: {
            url: 'https://bsc-testnet.public.blastapi.io',
            accounts: [process.env.PRIVATE_KEY],
        }

    },

};