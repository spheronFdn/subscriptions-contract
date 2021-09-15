const { BigNumber } = require("@ethersproject/bignumber");
const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("ArGo Subscription Data test cases", function() {
    const amount = ethers.BigNumber.from("100").mul(ethers.BigNumber.from(10).pow(18))
    const amount2 = ethers.BigNumber.from("110").mul(ethers.BigNumber.from(10).pow(18))
    const amount3 = ethers.BigNumber.from("120").mul(ethers.BigNumber.from(10).pow(18))
    let tokenAmount = ethers.BigNumber.from("100000").mul(ethers.BigNumber.from(10).pow(18))
    let approvalAmount = ethers.BigNumber.from("1000").mul(ethers.BigNumber.from(10).pow(18))
    let Staking;
    let staking;
    let SubscriptionData;
    let subscriptionData;
    let SubscriptionPayments;
    let subscriptionPayments;
    let Token;
    let token;
    let first, second, third, vault;
    let params = ["build", "sockets", "hooks"]
    let prices = [BigNumber.from("12").mul(ethers.BigNumber.from(10).pow(18)), BigNumber.from("1").mul(ethers.BigNumber.from(10).pow(18)), BigNumber.from("10").mul(ethers.BigNumber.from(10).pow(18))]
    let priceFeed = "0x987aeea14c3638766ef05f66e64f7ea38ddc8dcd"
    const discountSlabs = [amount, amount2, amount3];
    const discountPercents = [10, 15, 20];
    const priceFeedSymbol = "ARGO/USD";
    const epochDuration = 604800;
    let epoch1Start;
    const PRECISION = BigNumber.from(10).pow(BigNumber.from(25))
    const PERCENT = BigNumber.from(100).mul(PRECISION)

    beforeEach(async() => {
        epoch1Start = Math.floor(Date.now() / 1000) + 1000;
        [first, second, third, vault] = await ethers.getSigners();
        Token = await ethers.getContractFactory("ARGO")
        token = await Token.deploy(tokenAmount)
        await token.deployed();
        token.transfer(second.address, tokenAmount)
        SubscriptionData = await ethers.getContractFactory("SubscriptionData");
        Staking = await ethers.getContractFactory("StakingMock");
        staking = await Staking.connect(first).deploy(epoch1Start, epochDuration, vault.address);
        subscriptionData = await SubscriptionData.deploy(params, prices, token.address, third.address, discountSlabs, discountPercents, priceFeed, token.address, priceFeedSymbol);
        await subscriptionData.deployed()
        SubscriptionPayments = await ethers.getContractFactory("SubscriptionPayments");
        subscriptionPayments = await SubscriptionPayments.deploy(subscriptionData.address);
        await subscriptionPayments.deployed()


    })
    it("Contract should deploy at correct state", async function() {
        const dataContract = await subscriptionPayments.subscriptionData();
        expect(dataContract.toLowerCase()).to.be.equal(subscriptionData.address.toLowerCase());

    });
    it("Data contract address should not be zero", async function() {
        subscriptionData = SubscriptionPayments.deploy("0x0000000000000000000000000000000000000000");
        await expect(subscriptionData).to.be.revertedWith("ArgoSubscriptionPayments: SubscriptionData contract address can not be zero address");
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
        await token.connect(second).approve(subscriptionPayments.address, tokenAmount)
        await subscriptionPayments.chargeUser(second.address, _params, _values);
        let fee = BigNumber.from("0");
        for (let i = 0; i < _params.length; i++) {
            fee = fee.add((await subscriptionData.priceData(_params[i])).mul(_values[i]));
        }
        let underlying = fee.mul(ethers.BigNumber.from(10).pow(18)).div(await subscriptionData.getUnderlyingPrice())
        expect(await token.balanceOf(third.address)).to.be.equal(underlying);
    });
    it("Should charge correct amount with discount", async function() {
        let _params = ["build", "sockets", "hooks"]
        await token.connect(second).approve(staking.address, tokenAmount);
        await staking.connect(second).deposit(token.address, amount2);
        await subscriptionData.enableDiscounts(staking.address)
        let _values = [BigNumber.from("10"), BigNumber.from("1"), BigNumber.from("2")]
        await token.connect(second).approve(subscriptionPayments.address, tokenAmount)
        await subscriptionPayments.chargeUser(second.address, _params, _values);
        let fee = BigNumber.from("0");
        for (let i = 0; i < _params.length; i++) {
            fee = fee.add((await subscriptionData.priceData(_params[i])).mul(_values[i]));
        }
        fee = fee.sub(fee.mul(BigNumber.from(15)).mul(PRECISION).div(PERCENT))
        let underlying = fee.mul(ethers.BigNumber.from(10).pow(18)).div(await subscriptionData.getUnderlyingPrice())
        expect(await token.balanceOf(third.address)).to.be.equal(underlying);
    });

})