const { BigNumber } = require("@ethersproject/bignumber");
const { expect, assert } = require("chai");

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
    let Token;
    let token;
    let first, second, third, vault;
    let params = ["build", "sockets", "hooks"]
    let prices = [BigNumber.from("10"), BigNumber.from("1"), BigNumber.from("10")]
    let priceFeed = "0x987aeea14c3638766ef05f66e64f7ea38ddc8dcd"
    const discountSlabs = [amount, amount2, amount3];
    const discountPercents = [10, 15, 20];
    const priceFeedSymbol = "ARGO/USD";
    const epochDuration = 604800;
    let epoch1Start;
    const argoPriceAtLastBlock = BigNumber.from("270980320000000000");
    beforeEach(async() => {
        epoch1Start = Math.floor(Date.now() / 1000) + 1000;
        [first, second, third, vault] = await ethers.getSigners();
        Token = await ethers.getContractFactory("ARGO")
        token = await Token.deploy(tokenAmount)
        await token.deployed();
        SubscriptionData = await ethers.getContractFactory("SubscriptionData");
        Staking = await ethers.getContractFactory("StakingMock");
        staking = await Staking.connect(first).deploy(epoch1Start, epochDuration, vault.address);
        subscriptionData = await SubscriptionData.deploy(params, prices, token.address, third.address, discountSlabs, discountPercents, priceFeed, token.address, priceFeedSymbol);
        await subscriptionData.deployed()

    })
    it("Contract should deploy at correct state", async function() {
        const tokenAddress = await subscriptionData.underlying();
        expect(tokenAddress).to.be.equal(token.address);
        const escrow = await subscriptionData.escrow();
        expect(escrow).to.be.equal(third.address);
        const priceFeedAggregator = await subscriptionData.priceFeed();
        expect(priceFeedAggregator.toLowerCase()).to.be.equal(priceFeed);
        const feederSymobl = await subscriptionData.feederSymbol();
        expect(feederSymobl).to.be.equal(priceFeedSymbol);
        const stakedToken = await subscriptionData.stakedToken();
        expect(stakedToken).to.be.equal(token.address);
        let bool = true;
        let count = 0;
        while (bool) {
            try {
                await subscriptionData.discountSlabs(count);
                count++;
            } catch (e) {
                break;
            }
        }
        expect(count).to.be.equal(3);
        for (let i = 0; i < params.length; i++) {
            const price = await subscriptionData.priceData(params[i]);
            expect(price).to.be.equal(prices[i])
        }

    });
    it("Escrow address should be non zero should.", async function() {
        subscriptionData = SubscriptionData.deploy(params, prices, token.address, "0x0000000000000000000000000000000000000000", discountSlabs, discountPercents, priceFeed, token.address, priceFeedSymbol);
        await expect(subscriptionData).to.be.revertedWith("ArgoSubscriptionData: Escrow address can not be zero address");
    });
    it("Array of discount slab should be equal", async function() {
        let _slabs = [amount, amount2];

        subscriptionData = SubscriptionData.deploy(params, prices, token.address, third.address, _slabs, discountPercents, priceFeed, token.address, priceFeedSymbol);
        await expect(subscriptionData).to.be.revertedWith("ArgoSubscriptionData: discount slabs array and discount amount array have different size");
    });

    it("update params", async function() {
        const _params = ["sockets", "providers"]
        const _prices = [BigNumber.from("11"), BigNumber.from("10")]

        await subscriptionData.updateParams(_params, _prices);
        var price1 = await subscriptionData.priceData(_params[0])

        expect(price1).to.be.equal(_prices[0]);
        var price2 = await subscriptionData.priceData(_params[1]);
        expect(price2).to.be.equal(_prices[1]);

        var element = await subscriptionData.params(3);
        expect(element).to.be.equal(_params[1]);

    });
    it("delete params", async function() {
        const _params = ["sockets", "providers"]

        await subscriptionData.deleteParams(_params);
        var price1 = await subscriptionData.priceData(_params[0])

        expect(price1).to.be.equal(BigNumber.from("0"));
        var price2 = await subscriptionData.priceData(_params[1]);
        expect(price2).to.be.equal(BigNumber.from("0"));
        var element = subscriptionData.params(3);
        await expect(element).to.be.revertedWith("");

    });
    it("only manager should be able update or delete params", async function() {
        const _params = ["sockets", "providers"]
        const _prices = [BigNumber.from("11"), BigNumber.from("10")]

        var tx = subscriptionData.connect(second).updateParams(_params, _prices);
        await expect(tx).to.be.revertedWith("Only manager and owner can call this function");
        tx = subscriptionData.connect(second).deleteParams(_params);
        await expect(tx).to.be.revertedWith("Only manager and owner can call this function");

    });
    it("only governance should be able update slabs", async function() {
        await subscriptionData.setGovernanceAddress(third.address);
        var tx = subscriptionData.updateDiscountSlabs(discountSlabs, discountPercents);
        await expect(tx).to.be.revertedWith("Caller is not the governance contract");
        await subscriptionData.connect(third).updateDiscountSlabs(discountSlabs, discountPercents);
    });
    it("token address should be non zero.", async function() {
        subscriptionData = SubscriptionData.deploy(params, prices, "0x0000000000000000000000000000000000000000", third.address, discountSlabs, discountPercents, priceFeed, token.address, priceFeedSymbol);
        await expect(subscriptionData).to.be.revertedWith("ArgoSubscriptionData: Token address can not be zero address");
    });
    it("staked token address should be non zero.", async function() {
        subscriptionData = SubscriptionData.deploy(params, prices, token.address, third.address, discountSlabs, discountPercents, priceFeed, "0x0000000000000000000000000000000000000000", priceFeedSymbol);
        await expect(subscriptionData).to.be.revertedWith("ArgoSubscriptionData: staked token address can not be zero address");
    });
    it("Should enable discounts", async function() {
        await subscriptionData.enableDiscounts(staking.address);
    });
    it("Should return correct discount slabs and percents", async function() {
        const slabs = await subscriptionData.slabs();
        const percents = await subscriptionData.discountPercents();
        const discountPercents = [BigNumber.from(10), BigNumber.from(15), BigNumber.from(20)]
        assert.deepEqual(slabs, discountSlabs)
        assert.deepEqual(percents, discountPercents)
    });
    it("Should update oracle feeder address", async function() {
        await subscriptionData.setGovernanceAddress(third.address);
        await subscriptionData.connect(third).updateFeederAddress(priceFeed);
    });
    it("Should update feeder feeder symbol", async function() {
        await subscriptionData.setGovernanceAddress(third.address);
        await subscriptionData.connect(third).updateFeederTokenSymbol("Ethereum");
    });
    it("Should update underlying token address", async function() {
        await subscriptionData.setGovernanceAddress(third.address);
        await subscriptionData.connect(third).updateUnderlyingToken(third.address);
        let address = await subscriptionData.underlying();
        expect(address).to.equal(third.address)

    });
    it("It should perform emergency withdraw", async function() {
        await token.transfer(subscriptionData.address, approvalAmount)
        var bal = await token.balanceOf(first.address);
        await subscriptionData.connect(first).withdrawERC20(token.address, approvalAmount);
        var bal1 = await token.balanceOf(first.address);
        expect(approvalAmount).to.equal(bal1.sub(bal))
    });
    it("Should pause", async function() {
        subscriptionData.connect(first).pause();
    });
    it("Should unpause charging", async function() {
        subscriptionData.connect(first).pause();
        subscriptionData.connect(first).unpause();

    });
    it("Should return underlying token price", async function() {
        const price = await subscriptionData.getUnderlyingPrice();
        expect(price).to.be.equal(argoPriceAtLastBlock);

    });

})