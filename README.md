<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/spheronFdn/fns/blob/main/.github/assets/spheron-logo-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/spheronFdn/fns/blob/main/.github/assets/spheron-logo.svg">
    <img alt="Spheron" src="https://github.com/spheronFdn/fns/blob/main/.github/assets/spheron-logo.svg" width="250">
  </picture>
</p>

  

<p  align="center">

🧰 Desub Contracts is a collection of Solidity smart contracts designed to facilitate decentralized recurring and one-time payments using cryptocurrencies for individuals and organizations. 

</p>

<p  align="center">

<img  src="https://img.shields.io/static/v1?label=npm&message=v14.0.0&color=green" />

<img  src="https://img.shields.io/static/v1?label=license&message=MIT&color=green" />

<a  href="https://discord.com/invite/ahxuCtm"  target="_blank"  rel="noreferrer">

<img  src="https://img.shields.io/static/v1?label=community&message=discord&color=blue" />

</a>

<a  href="https://twitter.com/SpheronFdn"  target="_blank"  rel="noreferrer">

<img  src="https://img.shields.io/twitter/url/https/twitter.com/cloudposse.svg?style=social&label=Follow%20%40SpheronFdn" />

</a>

</p>

  
  

# Desub Contracts
These contracts leverage the decentralized nature of blockchain technology to provide a secure, transparent, and tamper-proof payment system that eliminates the need for intermediaries. Through the use of these contracts, users can create subscription-based services and charge fees in cryptocurrencies such as Ether, USDC, DAI, and other ERC-20 tokens. Additionally, the Desub Contracts offer features such as automatic payment processing, refund handling and convenience of the payment system.

# Core Contracts
**SubscriptionData**: Solify Smart contract for a subscription service that allows users to purchase subscription parameters using various ERC20 tokens. The contract allows the owner to set prices for each subscription parameter and specify the accepted ERC20 tokens. The contract also supports a discount system for subscriptions, where users can receive discounts based on the number of tokens they hold and the total amount of tokens they have staked.

The contract is designed to be owned by a governance entity and allows for multiple owners. The contract also implements the OpenZeppelin's Ownable and SafeERC20 libraries for added security and convenience.

The purpose of this contract is to enable a subscription-based service that can be paid for using various ERC20 tokens. It also provides a discount system to incentivize users to hold and stake tokens. The contract is useful for any subscription-based service that wants to accept payments in ERC20 tokens and incentivize users to hold and stake their tokens.

**SubscriptionDePay**: SubscriptionDePay is used for subscription payments. Its purpose is to enable users to subscribe to a service or product and pay for it periodically, such as monthly or annually. The contract can handle multiple ERC20 tokens for payments, and it ensures that users are charged the correct amount for their subscription.

The contract allows users to deposit ERC20 tokens to the contract, and it tracks the total amount deposited per token. It also keeps track of the total charges, withdrawals, and company revenue per token. The contract supports pausing the deposit and withdrawal functions temporarily.

The contract has different roles, including a Manager role that can modify contract data, a Treasury role responsible for managing the multisig account, a Company role for managing the multisig account of the company, and an Owner role responsible for core functions such as setting the treasury and company addresses.

The use case for this smart contract is to provide a secure and transparent way for businesses to manage subscription payments for their services or products. It can be used by subscription-based businesses such as media platforms, online services, and e-commerce sites.

## Pre Deployment Configuaration
To deploy this contract to an EVM supported blockchain of your choice, follow this step 

1. ```npm install```
2. Edit the ```.env.sample``` file and add the correct details
3. Go to ```hardhat.config.js``` and add the network details
4. Make all neccessary changes in the ```deploy``` folder
5. Run the deployment script ```npx hardhat --network [networkName] deploy```


## Post Deployment Setup
1. Verify the deployed contract ```npx hardhat --network [networkName] etherscan-verify [--api-key <apikey>] [--apiurl <url>]``` OR ```npx hardhat --network [networkName] sourcify```
2. Set the GovernanceAddress on SubscriptionData
3. Call the addNewTokens(any ERC20 token) function on SubscriptionData
4. Set to subscription parameters using updateParams functions
5. Users can deposits and withdraw using userDeposit & userWithdraw
6. Make call to chargeUser function to deduct the user's fund.


## Contribution
We encourage you to read the [contribution guidelines](https://github.com/spheronFdn/fns/blob/main/.github/contribution-guidelines.md) to learn about our development process and how to propose bug fixes and improvements before submitting a pull request.

The Spheron community extends beyond issues and pull requests! You can support Spheron [in many other ways](https://github.com/spheronFdn/fns/blob/main/.github/support.md) as well.

## Community
For help, discussions or any other queries: [Join us on Discord](https://discord.com/invite/ahxuCtm)
