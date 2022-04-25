const {
  BN,
  constants,
  expectEvent,
  shouldFail,
} = require("openzeppelin-test-helpers");

const NFTMarket = artifacts.require("./NFTMarket");
const CreateCollection = artifacts.require("./CreateCollection");
const MarketPlaceFeeContract = artifacts.require("./MarketPlaceFeeContract");
const NFT = artifacts.require("./NFT");
const FractionalNFT = artifacts.require("./FractionalNFT");
const zeroAddress = "0x0000000000000000000000000000000000000000";

require("chai").use(require("chai-as-promised")).should();

const EVM_REVERT = "VM Exception while processing transaction: revert";

contract("NFTMarket", ([deployer, ...users]) => {
  let nftMarket,
    createCollection,
    marketPlaceFeeContract,
    NFT1,
    NFT2,
    FNFT1,
    FNFT2,
    NFT3,
    nft1,
    nft2,
    nft3,
    fnft1,
    fnft2,
    nft1Address,
    nft2Address,
    fnft1Address,
    fnft2Address;

  describe("NFTMarket", () => {
    beforeEach(async () => {
      createCollection = await CreateCollection.new();
      marketPlaceFeeContract = await MarketPlaceFeeContract.new(300);
      nftMarket = await NFTMarket.new(
        marketPlaceFeeContract.address,
        createCollection.address,
        deployer
      );
      await createCollection.changeMarketplaceAddress(nftMarket.address);
      NFT1 = await createCollection.createCollection(
        "ERC721 Sample 1",
        "SAM1",
        "Sample ERC721 contract 1",
        nftMarket.address,
        false,
        250,
        [users[0], users[1], users[2]],
        [3333, 3333, 3334],
        { from: deployer }
      );
      NFT2 = await createCollection.createCollection(
        "ERC721 Sample 2",
        "SAM2",
        "Sample ERC721 contract 2",
        nftMarket.address,
        false,
        250,
        [users[0], users[1], users[2], users[3]],
        [2500, 2500, 2000, 3000],
        { from: deployer }
      );
      FNFT1 = await createCollection.createCollection(
        "ERC1155 Sample 1",
        "SAM1",
        "Sample ERC1155 contract 1",
        nftMarket.address,
        true,
        300,
        [users[0], users[1]],
        [6000, 4000],
        { from: deployer }
      );
      FNFT2 = await createCollection.createCollection(
        "ERC1155 Sample 2",
        "SAM2",
        "Sample ERC1155 contract 2",
        nftMarket.address,
        true,
        300,
        [users[0], users[1], users[2]],
        [3000, 4500, 2500],
        { from: deployer }
      );
      NFT3 = await NFT.new(
        "ERC721 Sample 3",
        "SAM3",
        nftMarket.address,
        deployer
      );

      nft1Address = NFT1.logs[0].args._newCollection;
      nft2Address = NFT2.logs[0].args._newCollection;
      fnft1Address = FNFT1.logs[0].args._newCollection;
      fnft2Address = FNFT2.logs[0].args._newCollection;
      nft1 = new web3.eth.Contract(NFT.abi, nft1Address);
      nft2 = new web3.eth.Contract(NFT.abi, nft2Address);
      fnft1 = new web3.eth.Contract(FractionalNFT.abi, fnft1Address);
      fnft2 = new web3.eth.Contract(FractionalNFT.abi, fnft2Address);
    });
    describe("Create Collection", async () => {
      it("Creates an ERC721 Collection", async () => {
        let collectionName = await nft1.methods.name().call();
        let collectionNameInMarket = await nftMarket.addressToCollection(
          nft1Address
        );
        collectionName.should.equal(collectionNameInMarket.name);
        let collections = await nftMarket.collections(0);
        collections.should.equal(nft1Address);
        let creatorObject = await nftMarket.creatorFees(nft1Address, 0);
        creatorObject.creator.should.equal(users[0]);
      });

      it("Creates an ERC1155 Collection", async () => {
        let collectionName = await fnft1.methods.name().call();
        let collectionNameInMarket = await nftMarket.addressToCollection(
          fnft1Address
        );
        collectionName.should.equal(collectionNameInMarket.name);
        let collections = await nftMarket.collections(2);
        collections.should.equal(fnft1Address);
        let creatorObject = await nftMarket.creatorFees(fnft1Address, 0);
        creatorObject.creator.should.equal(users[0]);
      });

      // it("Returns the symbol", async () => {
      //   result = await openEmoji.symbol();
      //   result.should.equal(SYMBOL);
      // });

      // it("Returns the cost to mint", async () => {
      //   result = await openEmoji.cost();
      //   result.toString().should.equal("0");
      // });

      // it("Returns the max supply", async () => {
      //   result = await openEmoji.maxSupply();
      //   result.toString().should.equal("138");
      // });

      // it("Returns the max mint amount", async () => {
      //   result = await openEmoji.maxMintAmount();
      //   result.toString().should.equal("1");
      // });

      // it("Returns the time deployed", async () => {
      //   result = await openEmoji.timeDeployed();

      //   if (result > 0) {
      //     assert.isTrue(true);
      //   } else {
      //     console.log(result);
      //     assert.isTrue(false);
      //   }
      // });

      // it("Returns the amount of seconds from deployment to wait until minting", async () => {
      //   let buffer = 2;
      //   let target = Number(milliseconds.toString().slice(0, 3));
      //   result = await openEmoji.allowMintingAfter();
      //   result = Number(result);

      //   // NOTE: Sometimes the seconds may be off by 1, As long as the seconds are
      //   // between the buffer zone, we'll pass the test
      //   if (result > target - buffer && result <= target) {
      //     assert.isTrue(true);
      //   } else {
      //     assert.isTrue(false);
      //   }
      // });

      // it("Returns how many seconds left until minting allowed", async () => {
      //   let buffer = 2;
      //   let target = Number(milliseconds.toString().slice(0, 3));
      //   result = await openEmoji.getSecondsUntilMinting();
      //   result = Number(result);

      //   // NOTE: Sometimes the seconds may be off by 1, As long as the seconds are
      //   // between the buffer zone, we'll pass the test
      //   if (result > target - buffer && result <= target) {
      //     assert.isTrue(true);
      //   } else {
      //     assert.isTrue(false);
      //   }
      // });

      // it("Returns current pause state", async () => {
      //   result = await openEmoji.isPaused();
      //   result.toString().should.equal("false");
      // });

      // it("Returns current reveal state", async () => {
      //   result = await openEmoji.isRevealed();
      //   result.toString().should.equal("true");
      // });
    });
    describe("Import Collection", async () => {
      it("Imports a collection", async () => {
        await nftMarket.importCollection(
          NFT3.address,
          "Sample ERC721 contract 3"
        );
        let collectionNameInMarket = await nftMarket.addressToCollection(
          NFT3.address
        );
        collectionNameInMarket.name.should.equal("ERC721 Sample 3");
      });
    });
    describe("Creator Fees", async () => {
      it("Request creator fees as outsider", async () => {
        await nftMarket.requestCreatorFees(
          NFT3.address,
          [users[0], users[1]],
          [4000, 6000],
          { from: users[1] }
        );
        const creatorRequest = await nftMarket.creatorRequests(0);
        creatorRequest.nftContract.should.equal(NFT3.address);
      });
      it("Request creator fees as owner", async () => {
        await nftMarket.requestCreatorFees(
          NFT3.address,
          [users[0], users[1]],
          [4000, 6000],
          { from: deployer }
        );
        const creatorFees = await nftMarket.creatorFees(NFT3.address, 0);
        const share = new BN(creatorFees.shareInPercentage);
        share.toNumber().should.equal(4000);
      });
    });
    describe("Asks and Bids", async () => {
      beforeEach(async () => {
        await nft1.methods
          .createToken("https://velasart.io")
          .send({ from: deployer, gas: 4500000 });
        await nft2.methods
          .createToken("https://velasart.io")
          .send({ from: deployer, gas: 4500000 });
        await nft2.methods
          .createToken("https://velasart.io")
          .send({ from: deployer, gas: 4500000 });
        await fnft1.methods
          .createToken(50, "https://velasart.io")
          .send({ from: deployer, gas: 4500000 });
        await fnft2.methods
          .createToken(100, "https://velasart.io")
          .send({ from: deployer, gas: 4500000 });
        await fnft2.methods
          .createToken(150, "https://velasart.io")
          .send({ from: deployer, gas: 4500000 });
      });

      it("Creates Asks and Bids", async () => {
        await nft1.methods
          .setApprovalForAll(nftMarket.address, true)
          .send({ from: deployer, gas: 4500000 });
        await nftMarket.ask(
          [nft1Address],
          [1],
          [web3.utils.toWei("1", "ether")],
          [1]
        );
        let seller = (await nftMarket.asks(nft1Address, 1, 0)).seller;
        seller.should.equal(deployer);
        await nft2.methods
          .setApprovalForAll(nftMarket.address, true)
          .send({ from: deployer, gas: 4500000 });
        await nftMarket.ask(
          [nft2Address],
          [2],
          [web3.utils.toWei("0.5", "ether")],
          [1]
        );
        seller = (await nftMarket.asks(nft2Address, 2, 0)).seller;
        seller.should.equal(deployer);
        await fnft1.methods
          .setApprovalForAll(nftMarket.address, true)
          .send({ from: deployer, gas: 4500000 });
        await nftMarket.ask(
          [fnft1Address],
          [1],
          [web3.utils.toWei("1", "ether")],
          [10]
        );
        seller = (await nftMarket.asks(fnft1Address, 1, 0)).seller;
        seller.should.equal(deployer);
        await fnft2.methods
          .setApprovalForAll(nftMarket.address, true)
          .send({ from: deployer, gas: 4500000 });
        await nftMarket.ask(
          [fnft2Address],
          [2],
          [web3.utils.toWei("0.5", "ether")],
          [10]
        );
        seller = (await nftMarket.asks(fnft2Address, 2, 0)).seller;
        seller.should.equal(deployer);

        // bids
        await nftMarket.bid(
          [nft1Address],
          [1],
          [web3.utils.toWei("0.5", "ether")],
          [1],
          {
            value: web3.utils.toWei("0.5", "ether"),
          }
        );
        let buyer = (await nftMarket.bids(nft1Address, 1, 0)).buyer;
        buyer.should.equal(deployer);
        await nftMarket.bid(
          [nft2Address],
          [2],
          [web3.utils.toWei("0.3", "ether")],
          [1],
          {
            value: web3.utils.toWei("0.3", "ether"),
          }
        );
        buyer = (await nftMarket.bids(nft2Address, 2, 0)).buyer;
        buyer.should.equal(deployer);
        await nftMarket.bid(
          [fnft1Address],
          [1],
          [web3.utils.toWei("0.5", "ether")],
          [10],
          {
            value: web3.utils.toWei("5", "ether"),
          }
        );
        buyer = (await nftMarket.bids(fnft1Address, 1, 0)).buyer;
        buyer.should.equal(deployer);
        await nftMarket.bid(
          [fnft2Address],
          [2],
          [web3.utils.toWei("0.3", "ether")],
          [10],
          {
            value: web3.utils.toWei("3", "ether"),
          }
        );
        buyer = (await nftMarket.bids(fnft2Address, 2, 0)).buyer;
        buyer.should.equal(deployer);
      });
      it("Cancels Asks and Bids", async () => {
        // Create Ask
        await nft1.methods
          .setApprovalForAll(nftMarket.address, true)
          .send({ from: deployer, gas: 4500000 });
        await nftMarket.ask(
          [nft1Address],
          [1],
          [web3.utils.toWei("1", "ether")],
          [1]
        );
        // Create Bid
        await nftMarket.bid(
          [nft1Address],
          [1],
          [web3.utils.toWei("0.5", "ether")],
          [1],
          {
            value: web3.utils.toWei("0.5", "ether"),
          }
        );

        // Cancel Ask
        await nftMarket.cancelAsk([nft1Address], [1], [0]);
        let seller = (await nftMarket.asks(nft1Address, 1, 0)).seller;
        seller.should.not.equal(deployer);

        // Cancel Bid
        await nftMarket.cancelBid([nft1Address], [1], [0]);
        let buyer = (await nftMarket.bids(nft1Address, 1, 0)).buyer;
        buyer.should.not.equal(deployer);
      });
      it("Accepts Asks", async () => {
        // Create Ask
        await nft1.methods
          .setApprovalForAll(nftMarket.address, true)
          .send({ from: deployer, gas: 4500000 });
        await nftMarket.ask(
          [nft1Address],
          [1],
          [web3.utils.toWei("1", "ether")],
          [1]
        );

        // Accept Ask
        await nftMarket.acceptAsk([nft1Address], [1], [1], [0], {
          from: users[0],
          gas: 4500000,
          value: web3.utils.toWei("1", "ether"),
        });
        let seller = (await nftMarket.asks(nft1Address, 1, 0)).seller;
        seller.should.not.equal(deployer);
      });
      it("Accepts Bids", async () => {
        // Create Ask
        await nft1.methods
          .setApprovalForAll(nftMarket.address, true)
          .send({ from: deployer, gas: 4500000 });
        // Create Bid
        await nftMarket.bid(
          [nft1Address],
          [1],
          [web3.utils.toWei("0.5", "ether")],
          [1],
          { from: users[0], value: web3.utils.toWei("0.5", "ether") }
        );

        // Accept Bid
        await nftMarket.acceptBid([nft1Address], [1], [1], [0], {
          from: deployer,
          gas: 4500000,
        });
        let buyer = (await nftMarket.bids(nft1Address, 1, 0)).buyer;
        buyer.should.not.equal(deployer);
      });
    });
  });

  // describe("Minting", async () => {
  //   describe("Success", async () => {
  //     let result;

  //     beforeEach(async () => {
  //       const NFT_MINT_DATE = Date.now().toString().slice(0, 10);

  //       openEmoji = await OpenEmoji.new(
  //         NAME,
  //         SYMBOL,
  //         IPFS_IMAGE_METADATA_URI,
  //         IPFS_HIDDEN_IMAGE_METADATA_URI,
  //         NFT_MINT_DATE
  //       );

  //       result = await openEmoji.mint(1, {
  //         from: user,
  //         value: web3.utils.toWei("0", "ether"),
  //       });
  //     });

  //     it("Returns the address of the minter", async () => {
  //       let event = result.logs[0].args;
  //       event.to.should.equal(user);
  //     });

  //     it("Updates the total supply", async () => {
  //       result = await openEmoji.totalSupply();
  //       result.toString().should.equal("1");
  //     });

  //     it("Returns IPFS URI", async () => {
  //       result = await openEmoji.tokenURI(1);
  //       result.should.equal(`${IPFS_IMAGE_METADATA_URI}1.json`);
  //     });

  //     it("Returns how many a minter owns", async () => {
  //       result = await openEmoji.balanceOf(user);
  //       result.toString().should.equal("1");
  //     });

  //     it("Returns the IDs of minted NFTs", async () => {
  //       result = await openEmoji.walletOfOwner(user);
  //       result.length.should.equal(1);
  //       result[0].toString().should.equal("1");
  //     });
  //   });

  //   describe("Failure", async () => {
  //     let result;

  //     beforeEach(async () => {
  //       // Some date in the future
  //       const NFT_MINT_DATE = new Date("Nov 04, 2021 18:00:00")
  //         .getTime()
  //         .toString()
  //         .slice(0, 10);

  //       openEmoji = await OpenEmoji.new(
  //         NAME,
  //         SYMBOL,
  //         IPFS_IMAGE_METADATA_URI,
  //         IPFS_HIDDEN_IMAGE_METADATA_URI,
  //         NFT_MINT_DATE
  //       );
  //     });

  //     it("Attempt to mint before mint date", async () => {
  //       await openEmoji
  //         .mint(1, { from: user, value: web3.utils.toWei("0", "ether") })
  //         .should.be.rejectedWith(EVM_REVERT);
  //     });

  //     it("Attempt to mint more than 1", async () => {
  //       await openEmoji
  //         .mint(1, { from: user, value: web3.utils.toWei("0", "ether") })
  //         .should.be.rejectedWith(EVM_REVERT);
  //       await openEmoji
  //         .mint(1, { from: user, value: web3.utils.toWei("0", "ether") })
  //         .should.be.rejectedWith(EVM_REVERT);
  //     });
  //   });
  // });

  // describe("Updating Contract State", async () => {
  //   describe("Success", async () => {
  //     let result;

  //     beforeEach(async () => {
  //       const NFT_MINT_DATE = Date.now().toString().slice(0, 10);

  //       openEmoji = await OpenEmoji.new(
  //         NAME,
  //         SYMBOL,
  //         IPFS_IMAGE_METADATA_URI,
  //         IPFS_HIDDEN_IMAGE_METADATA_URI,
  //         NFT_MINT_DATE
  //       );
  //     });

  //     it("Sets the cost", async () => {
  //       let cost = web3.utils.toWei("1", "ether");
  //       await openEmoji.setCost(cost, { from: deployer });
  //       result = await openEmoji.cost();
  //       result.toString().should.equal(cost);
  //     });

  //     it("Sets the pause state", async () => {
  //       let isPaused = true; // Opposite of the default contract state
  //       await openEmoji.setIsPaused(isPaused, { from: deployer });
  //       result = await openEmoji.isPaused();
  //       result.toString().should.equal(isPaused.toString());
  //     });

  //     it("Sets the reveal state", async () => {
  //       let isRevealed = false; // Opposite of the default contract state
  //       await openEmoji.setIsRevealed(isRevealed, { from: deployer });
  //       result = await openEmoji.isRevealed();
  //       result.toString().should.equal(isRevealed.toString());
  //     });

  //     it("Sets the max batch mint amount", async () => {
  //       let amount = 5; // Different from the default contract state
  //       await openEmoji.setmaxMintAmount(5, { from: deployer });
  //       result = await openEmoji.maxMintAmount();
  //       result.toString().should.equal(amount.toString());
  //     });

  //     it("Sets the IPFS not revealed URI", async () => {
  //       let uri = "ipfs://IPFS-NEW-IMAGE-METADATA-CID/"; // Different from the default contract state
  //       await openEmoji.setNotRevealedURI(uri, { from: deployer });
  //       result = await openEmoji.notRevealedUri();
  //       result.toString().should.equal(uri);
  //     });

  //     it("Sets the base extension", async () => {
  //       let extension = ".example"; // Different from the default contract state
  //       await openEmoji.setBaseExtension(".example", { from: deployer });
  //       result = await openEmoji.baseExtension();
  //       result.toString().should.equal(extension);
  //     });
  //   });
  // });
});
