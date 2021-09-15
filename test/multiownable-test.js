const { expect } = require("chai");
const { ethers } = require("hardhat");
let multiOwnable;
let MultiOwnable;
let first, second, third;
describe("MultiOwnable test cases", function() {
    beforeEach(async() => {
        [first, second, third] = await ethers.getSigners();
        MultiOwnable = await ethers.getContractFactory("MultiOwnable");
        multiOwnable = await MultiOwnable.deploy();
    })
    it("Should set array of managers", async function() {
        await multiOwnable.setManagers([second.address, third.address]);
        var managers = await multiOwnable.getManagers();
        expect(managers).to.be.deep.equal([second.address, third.address])

    });
    it("Should remove array of managers", async function() {
        await multiOwnable.setManagers([second.address, third.address]);
        await multiOwnable.removeManagers([second.address]);
        var managers = await multiOwnable.getManagers();
        expect(managers).to.be.deep.equal([third.address])

    });
    it("Should change  owner", async function() {
        await multiOwnable.changeOwner(second.address);
        var owner = await multiOwnable.owner();
        expect(owner).to.be.deep.equal(second.address)

    });
    it("Should revert when manager calls owner functions", async function() {
        var tx = multiOwnable.connect(second).changeOwner(second.address);
        await expect(tx).to.be.revertedWith("Only owner can call this function")

    });
})