const Migrations = artifacts.require("Migrations");
const NFT = artifacts.require("NFT");
const NFTMarket = artifacts.require("NFTMarket");

module.exports = function (deployer) {
  deployer.deploy(
    NFTMarket,
    "0x0000000000000000000000000000000000000000",
    "0x0000000000000000000000000000000000000000",
    "0x0000000000000000000000000000000000000000"
  );
};
