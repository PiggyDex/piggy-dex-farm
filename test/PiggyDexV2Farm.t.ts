import { expect } from "chai";
import { ethers } from "hardhat";


describe("Token contract", function () {
  it("Deploy successfully", async function () {
    const [owner] = await ethers.getSigners();

    const piggy = await ethers.deployContract("Piggy");

    const piggyDexV2Farm = await ethers.deployContract("PiggyDexV2Farm");

    const piggyAddress = await piggy.getAddress();
    const firstLpToken = "0x8a961ec47bde8639350c9fd39b66de1bbd2ba7dd";

    await piggyDexV2Farm.initialize(piggyAddress, 1000, owner.address, firstLpToken, piggyAddress, 0);

    expect((await piggyDexV2Farm.nativeToken())).to.equal(piggyAddress);
    expect((await piggyDexV2Farm.owner())).to.equal(owner.address);
    expect(await piggyDexV2Farm.getAllPoolsLength()).to.equal(1);

    const stakingPool = await ethers.deployContract("StakingPool", [
      piggy,
      piggyDexV2Farm,
      owner.address,
      owner.address,
      0,
    ])

    // const farmBooster = await ethers.deployContract("FarmBooster", [
    //   piggy,

    // ])
  });

  it("")
});
