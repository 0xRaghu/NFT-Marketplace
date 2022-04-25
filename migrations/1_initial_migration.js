const Migrations = artifacts.require("Migrations");
const NFT = artifacts.require("NFT");
const NFTMarket = artifacts.require("NFTMarket");
const CreateCollection = artifacts.require("CreateCollection");
const MarketPlaceFeeContract = artifacts.require("MarketPlaceFeeContract");

const zeroAddress = "0x0000000000000000000000000000000000000000";
const beneficiary = "0x04D92f8aa65f94581a2Be4cd612b83198E6cEa08";

module.exports = async function (deployer, network, accounts) {
  console.log(accounts);
  // await deployer.deploy(CreateCollection);
  // await deployer.deploy(MarketPlaceFeeContract, 300);
  // await deployer.deploy(
  //   NFTMarket,
  //   CreateCollection.address,
  //   MarketPlaceFeeContract.address,
  //   beneficiary
  // );
  // let createCollectionContract = await CreateCollection.deployed();
  // await createCollectionContract.changeMarketplaceAddress(NFTMarket.address);
};
