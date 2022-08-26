const { BigNumber } = require("@ethersproject/bignumber");
const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe.skip("Spheron Subscription Payment test cases", function() {
    const amount = ethers.BigNumber.from("100").mul(ethers.BigNumber.from(10).pow(18))
    const amount2 = ethers.BigNumber.from("110").mul(ethers.BigNumber.from(10).pow(18))
    const amount3 = ethers.BigNumber.from("120").mul(ethers.BigNumber.from(10).pow(18))
    let tokenAmount = ethers.BigNumber.from("10000000").mul(ethers.BigNumber.from(10).pow(18))
    let approvalAmount = ethers.BigNumber.from("1000").mul(ethers.BigNumber.from(10).pow(18))
    let Staking;
    let staking;
    let SubscriptionData;
    let subscriptionData;
    let SubscriptionPayments;
    let subscriptionPayments;
    let Token;
    let token1, token2;
    let first, second, third, vault;
    let params = ["build", "sockets", "hooks"]
    const prices = [BigNumber.from(10).pow(17), BigNumber.from(5).mul(BigNumber.from(10).pow(17)), BigNumber.from(10).pow(16)]
    let priceFeed = "0x987aeea14c3638766ef05f66e64f7ea38ddc8dcd"
    const discountSlabs = [amount, amount2, amount3];
    const discountPercents = [10, 15, 20];
    const priceFeedSymbol = "SPHE/USD";
    const epochDuration = 604800;
    let epoch1Start;
    const PRECISION = BigNumber.from(10).pow(BigNumber.from(25))
    const PERCENT = BigNumber.from(100).mul(PRECISION)

    const priceFeedSymbols = [priceFeedSymbol, "USDC"];
    const tokenDecimals = [18, 6];
    const isChainlink = [false, true];
    const feedAddress = ["0x987aeea14c3638766ef05f66e64f7ea38ddc8dcd", "0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0"];
    const feedPrecision = [8, 8]
    let tokenAddresses;
    beforeEach(async() => {
        epoch1Start = Math.floor(Date.now() / 1000) + 1000;
        [first, second, third, vault] = await ethers.getSigners();
        Token = await ethers.getContractFactory("SPHERON")
        token1 = await Token.deploy(tokenAmount)
        await token1.deployed();
        token2 = await Token.deploy(tokenAmount)
        await token2.deployed();
        token1.transfer(second.address, tokenAmount)
        token2.transfer(second.address, tokenAmount)
        tokenAddresses = [token1.address, token2.address];
        SubscriptionData = await ethers.getContractFactory("SubscriptionData");
        Staking = await ethers.getContractFactory("StakingMock");
        staking = await Staking.connect(first).deploy(epoch1Start, epochDuration, vault.address);
        await staking.deployed();
        subscriptionData = await SubscriptionData.deploy(params, prices, third.address, discountSlabs, discountPercents, token1.address);
        await subscriptionData.deployed()
        SubscriptionPayments = await ethers.getContractFactory("SubscriptionPayments");
        subscriptionPayments = await SubscriptionPayments.deploy(subscriptionData.address);
        await subscriptionPayments.deployed()
        await subscriptionData.setGovernanceAddress(third.address);
        await subscriptionData.connect(third).addNewTokens(priceFeedSymbols, tokenAddresses, tokenDecimals, isChainlink, feedAddress, feedPrecision);

    })
    it("Contract should deploy at correct state", async function() {
        const dataContract = await subscriptionPayments.subscriptionData();
        expect(dataContract.toLowerCase()).to.be.equal(subscriptionData.address.toLowerCase());

    });
    it("Data contract address should not be zero", async function() {
        subscriptionData = SubscriptionPayments.deploy("0x0000000000000000000000000000000000000000");
        await expect(subscriptionData).to.be.revertedWith("SubscriptionPayments: SubscriptionData contract address can not be zero address");
    });
    it("Should update data contract address", async function() {
        await subscriptionPayments.updateDataContract(third.address);
        let address = await subscriptionPayments.subscriptionData();
        expect(address.toLowerCase()).to.equal(third.address.toLowerCase())


    });
    it("Only Manager should be able to update data contract address", async function() {
        var tx = subscriptionPayments.connect(second).updateDataContract(third.address);
        await expect(tx).to.be.revertedWith("Only manager and owner can call this function");
    });


    it("Should charge correct amount to users", async function() {
        let _params = ["build", "sockets", "hooks"]
        let _values = [BigNumber.from("10"), BigNumber.from("1"), BigNumber.from("2")]
        await token2.connect(second).approve(subscriptionPayments.address, tokenAmount)
        await subscriptionPayments.chargeUser(second.address, _params, _values, token2.address);
        let fee = BigNumber.from("0");
        for (let i = 0; i < _params.length; i++) {
            fee = fee.add((await subscriptionData.priceData(_params[i])).mul(_values[i]));
        }
        fee = fee.div(BigNumber.from(10).pow(12));
        let underlying = fee.mul(ethers.BigNumber.from(10).pow(6)).div(await subscriptionData.getUnderlyingPrice(token2.address))
        expect(await token2.balanceOf(third.address)).to.be.equal(underlying);
    });
    it("Should charge correct amount with discount", async function() {
        let _params = ["build", "sockets", "hooks"]
        await token1.connect(second).approve(staking.address, tokenAmount);
        await staking.connect(second).deposit(token1.address, amount2);
        await subscriptionData.enableDiscounts(staking.address)
        let _values = [BigNumber.from("10"), BigNumber.from("1"), BigNumber.from("2")]
        await token1.connect(second).approve(subscriptionPayments.address, tokenAmount)
        await subscriptionPayments.chargeUser(second.address, _params, _values, token1.address);
        let fee = BigNumber.from("0");
        for (let i = 0; i < _params.length; i++) {
            fee = fee.add((await subscriptionData.priceData(_params[i])).mul(_values[i]));
        }
        fee = fee.sub(fee.mul(BigNumber.from(15)).mul(PRECISION).div(PERCENT))
        let underlying = fee.mul(ethers.BigNumber.from(10).pow(18)).div(await subscriptionData.getUnderlyingPrice(token1.address))
        expect(await token1.balanceOf(third.address)).to.be.equal(underlying);
    });

    it("Should charge user after adding tokens", async function () {
        let _params = ["build", "sockets", "hooks"]
        let _values = [BigNumber.from("10"), BigNumber.from("1"), BigNumber.from("2")]
        await subscriptionData.setGovernanceAddress(third.address);
        await subscriptionData.connect(third).addNewTokens(priceFeedSymbols, tokenAddresses, tokenDecimals, isChainlink, feedAddress, feedPrecision);
        let fee = BigNumber.from("0");
        let underlying = await subscriptionData.getUnderlyingPrice(token1.address);
        for (let i = 0; i < _params.length; i++) {
            let price = await subscriptionData.priceData(_params[i]);
            fee = fee.add(price.mul(_values[i]));
        }
        fee = fee.mul(BigNumber.from(10).pow(18)).div(underlying) 
        await token1.connect(second).approve(subscriptionPayments.address, fee)
        await subscriptionPayments.connect(first).chargeUser(second.address, _params, _values, token1.address);
        var bal = token1.balanceOf(third.address);
        expect(await bal).to.equal(fee)
    });

    it("Should not charge users after removing token", async function () {
        let _params = ["build", "sockets", "hooks"]
        let _values = [BigNumber.from("10"), BigNumber.from("1"), BigNumber.from("2")]
        await subscriptionData.setGovernanceAddress(third.address);
        await subscriptionData.connect(third).removeTokens([token1.address]);
        let underlying = await subscriptionData.getUnderlyingPrice(token1.address);
        let fee = BigNumber.from("0");
        for (let i = 0; i < _params.length; i++) {
            fee = fee.add((await subscriptionData.priceData(_params[i])).mul(_values[i]));
        }
        fee = fee.sub(fee.mul(BigNumber.from(15)).mul(PRECISION).div(PERCENT))  
        fee = fee.mul(underlying).div(BigNumber.from(10).pow(18)) 
        await token1.connect(second).approve(subscriptionPayments.address, fee)
        let tx = subscriptionPayments.connect(first).chargeUser(second.address, _params, _values, token1.address);
        await expect(tx).to.be.revertedWith("SubscriptionPayments: Token not accepted");
    });

})