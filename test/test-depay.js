const { BigNumber } = require("@ethersproject/bignumber");
const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("Spheron Subscription Decentralized Payment test cases", function() {
    const amount = ethers.BigNumber.from("100").mul(ethers.BigNumber.from(10).pow(18))
    const amount2 = ethers.BigNumber.from("110").mul(ethers.BigNumber.from(10).pow(18))
    const amount3 = ethers.BigNumber.from("120").mul(ethers.BigNumber.from(10).pow(18))
    const amount4 = ethers.BigNumber.from("100").mul(ethers.BigNumber.from(10).pow(18))
    const amount5 = ethers.BigNumber.from("50").mul(ethers.BigNumber.from(10).pow(18))
    const amount6 = ethers.BigNumber.from("35").mul(ethers.BigNumber.from(10).pow(18))
    let tokenAmount = ethers.BigNumber.from("10000000").mul(ethers.BigNumber.from(10).pow(18))
    let approvalAmount = ethers.BigNumber.from("1000").mul(ethers.BigNumber.from(10).pow(18))
    let Staking;
    let staking;
    let SubscriptionData;
    let subscriptionData;
    let SubscriptionDePay;
    let subscriptionDePay;
    let Token;
    let token1, token2;
    let first, second, third, vault, treasury, company, newTreasury, newCompany;
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
        [first, second, third, vault, treasury, trustForwarded, company, newTreasury, newCompany] = await ethers.getSigners();
        Token = await ethers.getContractFactory("SPHERON")
        token1 = await Token.deploy(tokenAmount)
        await token1.deployed();
        token2 = await Token.deploy(tokenAmount)
        await token2.deployed();
        token3 = await Token.deploy(tokenAmount)
        await token3.deployed();
        token4 = await Token.deploy(tokenAmount)
        await token4.deployed();
        token1.transfer(second.address, tokenAmount)
        token2.transfer(second.address, tokenAmount)
        tokenAddresses = [token1.address, token2.address];
        newtokenAddresses = [token3.address, token4.address];
        SubscriptionData = await ethers.getContractFactory("SubscriptionData");
        Staking = await ethers.getContractFactory("StakingMock");
        staking = await Staking.connect(first).deploy(epoch1Start, epochDuration, vault.address);
        await staking.deployed();
        subscriptionData = await SubscriptionData.deploy(params, prices, third.address, discountSlabs, discountPercents, token1.address);
        await subscriptionData.deployed()
        SubscriptionDePay = await ethers.getContractFactory("SubscriptionDePay");
        subscriptionDePay = await SubscriptionDePay.deploy(treasury.address, company.address, subscriptionData.address, trustForwarded.address);
        await subscriptionDePay.deployed()
        await subscriptionData.setGovernanceAddress(third.address);
        await subscriptionData.connect(third).addNewTokens(priceFeedSymbols, tokenAddresses, tokenDecimals, isChainlink, feedAddress, feedPrecision);

    })
    it("Contract should deploy at correct state", async function() {
        const dataContract = await subscriptionDePay.subscriptionData();
        expect(dataContract.toLowerCase()).to.be.equal(subscriptionData.address.toLowerCase());

    });
    it("Data contract address should not be zero", async function() {
        const dataContract = await subscriptionDePay.subscriptionData();
        await expect(dataContract).to.not.equal("0x0000000000000000000000000000000000000000");
    });
    it("Should update data contract address", async function() {
        await subscriptionDePay.updateDataContract(third.address);
        let address = await subscriptionDePay.subscriptionData();
        expect(address.toLowerCase()).to.equal(third.address.toLowerCase())


    });
    it("Only Manager should be able to update data contract address", async function() {
        var tx = subscriptionDePay.connect(second).updateDataContract(third.address);
        await expect(tx).to.be.revertedWith("Only manager and owner can call this function");
    });


    it("Should charge correct amount to users after deposit", async function() {
        let _params = ["build", "sockets", "hooks"]
        let _values = [BigNumber.from("10"), BigNumber.from("1"), BigNumber.from("2")]
        await token2.connect(second).approve(subscriptionDePay.address, tokenAmount);
        await subscriptionDePay.connect(second).userDeposit(token2.address, tokenAmount);
        await subscriptionDePay.chargeUser(second.address, _params, _values, token2.address);
        let fee = BigNumber.from("0");
        for (let i = 0; i < _params.length; i++) {
            fee = fee.add((await subscriptionData.priceData(_params[i])).mul(_values[i]));
        }
        fee = fee.div(BigNumber.from(10).pow(12));
        let figure = await subscriptionData.getUnderlyingPrice(token2.address);
        let underlying = fee.mul(ethers.BigNumber.from(10).pow(6)).div(figure.underlyingPrice);
        expect(await subscriptionDePay.getTotalCharges(token2.address)).to.be.equal(underlying);
    });
    it("Should enable user withdraw balance", async function() {
        await token2.connect(second).approve(subscriptionDePay.address, amount4);
        await subscriptionDePay.connect(second).userDeposit(token2.address, amount4);
        token2.connect(treasury).approve(subscriptionDePay.address, amount5);
        await subscriptionDePay.connect(second).userWithdraw(token2.address, amount5);
        let balance = await subscriptionDePay.getUserData(second.address, token2.address);
        let ball = (ethers.BigNumber.from(balance.balance));
        expect (ball).to.be.equal(amount5);
    });
    it("Should enable company withdraw balance", async function() {
        let _params = ["build", "sockets", "hooks"]
        let _values = [BigNumber.from("10"), BigNumber.from("1"), BigNumber.from("2")]
        let fee = BigNumber.from("0");
        for (let i = 0; i < _params.length; i++) {
            fee = fee.add((await subscriptionData.priceData(_params[i])).mul(_values[i]));
        }
        fee = fee.div(BigNumber.from(10).pow(12));
        let figure = await subscriptionData.getUnderlyingPrice(token2.address);
        let underlying = fee.mul(ethers.BigNumber.from(10).pow(6)).div(figure.underlyingPrice);
        await token2.connect(second).approve(subscriptionDePay.address, underlying);
        await subscriptionDePay.connect(second).userDeposit(token2.address, underlying);
        await subscriptionDePay.connect(first).chargeUser(second.address, _params, _values, token2.address);
        token2.connect(treasury).approve(subscriptionDePay.address, underlying);
        await subscriptionDePay.connect(company).companyWithdraw(token2.address, underlying);
        let balance = await subscriptionDePay.companyRevenue(token2.address);
        let ball = (ethers.BigNumber.from(balance));
        expect (ball).to.be.equal(BigNumber.from("0"));
    });

    it("Should charge user after adding tokens", async function () {
        let _params = ["build", "sockets", "hooks"]
        let _values = [BigNumber.from("10"), BigNumber.from("1"), BigNumber.from("2")]
        let fee = BigNumber.from("0");
        for (let i = 0; i < _params.length; i++) {
            fee = fee.add((await subscriptionData.priceData(_params[i])).mul(_values[i]));
        }
        fee = fee.div(BigNumber.from(10).pow(12));
        let figure = await subscriptionData.getUnderlyingPrice(token2.address);
        let underlying = fee.mul(ethers.BigNumber.from(10).pow(6)).div(figure.underlyingPrice); 
        await token2.connect(second).approve(subscriptionDePay.address, underlying)
        await subscriptionDePay.connect(second).userDeposit(token2.address, underlying);
        await subscriptionDePay.connect(first).chargeUser(second.address, _params, _values, token2.address);
        expect(await subscriptionDePay.getTotalCharges(token2.address)).to.be.equal(underlying);
    });

    it("Should not charge users after removing token", async function () {
        let _params = ["build", "sockets", "hooks"]
        let _values = [BigNumber.from("10"), BigNumber.from("1"), BigNumber.from("2")]
        await subscriptionData.setGovernanceAddress(third.address);
        await subscriptionData.connect(third).removeTokens([token1.address]);
        let underlying = subscriptionData.getUnderlyingPrice(token1.address);
        await expect(underlying).to.be.revertedWith("Token is not accepted");
    });
    it("it should set treasury by owner", async function () {
        await subscriptionDePay.connect(first).setTreasury(newTreasury.address);
        let address = await subscriptionDePay.treasury();
        expect(address.toLowerCase()).to.equal(newTreasury.address.toLowerCase())
    });

    it("it should restrict set to only owner or manager", async function () {
        let tx = subscriptionDePay.connect(second).setTreasury(newTreasury.address);
        await expect(tx).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should change company address", async function () {
        await subscriptionDePay.connect(company).setCompany(newCompany.address);
        await subscriptionDePay.connect(first).approveSetCompany();
        let address = await subscriptionDePay.company();
        expect(address.toLowerCase()).to.equal(newCompany.address.toLowerCase());
    });
    it("should change the deposit status", async function () {
        await subscriptionDePay.connect(first).changeDepositStatus();
        let status = await subscriptionDePay.pauseDeposit();
        expect(status).to.equal(true);
    });
    it("should change the withdrawal status", async function () {
        await subscriptionDePay.connect(first).changeWithdrawalStatus();
        let status = await subscriptionDePay.pauseWithdrawal();
        expect(status).to.equal(true);
    });
    it("should return correct user data", async function () {
        await token2.connect(second).approve(subscriptionDePay.address, amount6);
        await subscriptionDePay.connect(second).userDeposit(token2.address, amount6);
        let data = await subscriptionDePay.getUserData(second.address, token2.address);
        expect(data.deposit).to.equal(amount6);
    });
    it("should return total deposits", async function () {
        await token2.connect(second).approve(subscriptionDePay.address, amount6);
        await subscriptionDePay.connect(second).userDeposit(token2.address, amount6);
        await token2.connect(second).approve(subscriptionDePay.address, amount5);
        await subscriptionDePay.connect(second).userDeposit(token2.address, amount5);
        let data = await subscriptionDePay.getTotalDeposit(token2.address);
        expect(data).to.equal(amount6.add(amount5));
    });
    it("should retrun total withdrawals", async function () {
        await token2.connect(second).approve(subscriptionDePay.address, amount6);
        await subscriptionDePay.connect(second).userDeposit(token2.address, amount6);
        await token2.connect(second).approve(subscriptionDePay.address, amount5);
        await subscriptionDePay.connect(second).userDeposit(token2.address, amount5);
        token2.connect(treasury).approve(subscriptionDePay.address, amount6);
        await subscriptionDePay.connect(second).userWithdraw(token2.address, amount6);
        let data = await subscriptionDePay.getTotalWithdraws(token2.address);
        expect(data).to.equal(amount6);
    });


})