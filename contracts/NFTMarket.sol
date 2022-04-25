// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMarketPlaceFeeContract.sol";
import "./interfaces/IOwnableNFT.sol";
import "./NFT.sol";
import "./FractionalNFT.sol";

/// @author Velas Art Team
/// @title  NFT Marketplace on Velas Blockchain
contract NFTMarket is ReentrancyGuard, Ownable, ERC1155Holder, ERC721Holder {
    // STATE VARIABLES
    uint16 constant HUNDRED = 10000;
    IMarketPlaceFeeContract public feeContract;
    address private creatorContractAddress;

    mapping(address => uint256) public escrow;
    mapping(address => uint256) public allowedToWithdraw;

    mapping(address => Collection) public addressToCollection;
    mapping(address => uint256[]) public tokenIdsInCollection;

    mapping(address => Creator[]) public creatorFees;
    mapping(address => mapping(uint256 => Ask[])) public asks;
    mapping(address => mapping(uint256 => Bid[])) public bids;
    mapping(address => mapping(uint256 => uint256)) public lastTradedPrice;
    mapping(address => mapping(uint256 => SaleLog[])) public priceHistory;

    address[] public collections;

    address payable public beneficiary;

    struct Collection {
        bool isFractional;
        bool mintedOnMarketPlace;
        address createdBy;
        string name;
        string symbol;
        string description;
        string collectionSlug;
        uint16 creatorRoyaltyInPercentage;
        uint256 totalSupply;
        uint256 listedTime;
        uint256 volumeTraded;
    }

    struct Ask {
        bool exists;
        address seller;
        uint256 price;
        uint256 quantity;
        uint256 timestamp;
    }

    struct Bid {
        bool exists;
        address buyer;
        uint256 price;
        uint256 quantity;
        uint256 timestamp;
    }

    struct Creator {
        uint16 shareInPercentage;
        address payable creator;
    }

    struct UserAsk {
        address nftContract;
        uint256 tokenId;
        uint256 askIndex;
        uint256 price;
        uint256 quantity;
        uint256 timestamp;
    }

    struct UserBid {
        address nftContract;
        uint256 tokenId;
        uint256 bidIndex;
        uint256 price;
        uint256 quantity;
        uint256 timestamp;
    }

    struct SaleLog {
        address seller;
        address buyer;
        uint256 price;
        uint256 timestamp;
    }

    // EVENTS

    event CollectionCreated(
        uint256 collectionId,
        address _nftContract,
        string _name,
        string _symbol,
        uint256 timestamp
    );

    event AskCreated(
        address indexed nft,
        uint256 indexed tokenID,
        uint256 price,
        address indexed seller,
        uint256 quantity
    );

    event AskDeleted(
        address indexed nft,
        uint256 indexed tokenID,
        address indexed seller,
        uint256 price
    );

    event AskAccepted(
        address indexed nft,
        uint256 indexed tokenID,
        uint256 price,
        uint256 quantity,
        address indexed buyer
    );

    event BidCreated(
        address indexed nft,
        uint256 indexed tokenID,
        address indexed buyer,
        uint256 price,
        uint256 quantity
    );

    event BidDeleted(
        address indexed nft,
        uint256 indexed tokenID,
        address indexed buyer,
        uint256 price
    );

    event BidAccepted(
        address indexed nft,
        uint256 indexed tokenID,
        uint256 price,
        uint256 quantity,
        address indexed seller
    );

    event BidPayment(bool isCredit, address indexed user, Bid bid);

    event AskPayment(bool isCredit, address indexed user, Ask ask);

    event RoyaltyPayment(
        address indexed user,
        uint256 amount,
        address indexed nftContract,
        uint256 tokenId
    );

    event Withdrawal(address indexed payee, uint256 amount);

    // CONSTRUCTOR
    /**
     * @notice Initiates the contract with feeContract and creatorContractAddress
     * @param _feeContract              The instance of MarketPlaceFeeContract which is used by the marketplace for fee calculations
     * @param _creatorContractAddress   The collection creator contract used by the marketplace
     * @param _beneficiary              The beneficiary of Marketplace Fees
     */
    constructor(
        IMarketPlaceFeeContract _feeContract,
        address _creatorContractAddress,
        address payable _beneficiary
    ) {
        feeContract = _feeContract;
        creatorContractAddress = _creatorContractAddress;
        beneficiary = _beneficiary;
    }

    // EXTERNAL FUNCTIONS

    /**
     * @notice Imports a verified contract with creator royalties - Only callable by the creatorContract
     * @param _nftContract                  The address of NFT contract imported
     * @param _name                         Name of the NFT Contract
     * @param _symbol                       Symbol of the NFT Contract
     * @param _description                  Description of the NFT Contract
     * @param _collectionSlug               Slug of the collection
     * @param _isFractional                 True if the contract is ERC1155 compatible and False if ERC721
     * @param _creatorRoyaltyInPercentage   Creator Royalty in percentage scaled to 10^2
     * @param _creators                     Array of creator addresses that share the royalty
     * @param _percentages                  Array of percentages corresponding to the creators above
     * @param _createdBy                    Creator of the contract
     */
    function createCollection(
        address _nftContract,
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _collectionSlug,
        bool _isFractional,
        uint16 _creatorRoyaltyInPercentage,
        address payable[] memory _creators,
        uint16[] memory _percentages,
        address _createdBy
    ) public {
        require(
            msg.sender == creatorContractAddress || msg.sender == owner(),
            "UNAUTHORIZED"
        );
        require(
            addressToCollection[_nftContract].listedTime == 0,
            "EXISTING_COLLECTION"
        ); // Checks if collection already exists
        uint16 totalPercentage;
        for (uint256 i = 0; i < _percentages.length; i++) {
            totalPercentage += _percentages[i];
        }
        require(
            totalPercentage == 10000 || totalPercentage == 0,
            "TOTAL_PERCENTAGE_NOT_VALID"
        );
        Collection memory _tempCollection;

        uint256 totalSupply;
        if (msg.sender == creatorContractAddress) {
            totalSupply = 0;
            _tempCollection.mintedOnMarketPlace = true;
        } else {
            try IERC721Enumerable(_nftContract).totalSupply() returns (
                uint256 _totalSupply
            ) {
                totalSupply = _totalSupply;
            } catch {
                totalSupply = 0;
            }
            _tempCollection.mintedOnMarketPlace = false;
        }

        _tempCollection.name = _name;
        _tempCollection.symbol = _symbol;
        _tempCollection.description = _description;
        _tempCollection.collectionSlug = _collectionSlug;
        _tempCollection.isFractional = _isFractional;
        _tempCollection.totalSupply = totalSupply;
        _tempCollection.listedTime = block.timestamp;
        _tempCollection.createdBy = _createdBy;
        _tempCollection
            .creatorRoyaltyInPercentage = _creatorRoyaltyInPercentage;

        addressToCollection[_nftContract] = _tempCollection;
        collections.push(_nftContract);

        addCreatorFees(_nftContract, _creators, _percentages);

        emit CollectionCreated(
            collections.length, // array index will be the collectionId
            _nftContract,
            _name,
            _symbol,
            block.timestamp
        );
    }

    /**
     * @notice Creates an ask for (`nft`, `tokenID`) tuple for `price` and `quantity`
     * @dev Creating an ask requires msg.sender to have at least one qty of (`nft`, `tokenID`)
     * @param _nftContract  An array of ERC-721 and / or ERC-1155 addresses
     * @param _tokenId      Token Ids of the NFTs msg.sender wishes to sell
     * @param _price        Prices at which the seller is willing to sell the NFTs
     * @param _quantity     Number of tokens the seller is willing to sell. 1 if the NFT is ERC721 standard
     */
    function ask(
        address[] memory _nftContract,
        uint256[] memory _tokenId,
        uint256[] memory _price,
        uint256[] memory _quantity
    ) public {
        require(
            _nftContract.length == _tokenId.length &&
                _nftContract.length == _price.length &&
                _nftContract.length == _quantity.length,
            "ARRAY_LENGTHS_MISMATCH"
        );
        for (uint256 i = 0; i < _nftContract.length; i++) {
            address nftContract = _nftContract[i];
            uint256 tokenId = _tokenId[i];
            uint256 price = _price[i];
            uint256 quantity = _quantity[i];
            require(price > 0, "PRICE_LT_ZERO");
            require(
                quantityOf(nftContract, msg.sender, tokenId) > 0,
                "NOT_OWNER_OF_TOKEN"
            );
            require(isApproved(_nftContract[i]), "NOT_APPROVED_FOR_TRANSFER");

            if (!tokenIdExists(nftContract, tokenId)) {
                tokenIdsInCollection[nftContract].push(tokenId);
            }

            // There can be multiple asks for a tokenId in case of ERC1155 tokens
            asks[nftContract][tokenId].push(
                Ask({
                    exists: true,
                    seller: msg.sender,
                    price: price,
                    quantity: quantity,
                    timestamp: block.timestamp
                })
            );
            bool success = safeTransferFrom_(
                nftContract,
                tokenId,
                msg.sender,
                address(this),
                quantity,
                new bytes(0)
            );
            require(success, "REVERT_NFT_NOT_SENT");

            emit AskCreated({
                nft: address(nftContract),
                tokenID: tokenId,
                price: price,
                seller: msg.sender,
                quantity: quantity
            });
        }
    }

    /**
     * @notice Creates a bid on (`nft`, `tokenID`) tuple for `price`.
     * @dev Creating a bid requires msg.sender to pay the (bid amount - escrow balance) to the contract
     * @param _nftContract  An array of ERC-721 and / or ERC-1155 addresses
     * @param _tokenId      Token Ids of the NFTs msg.sender wishes to buy
     * @param _price        Prices at which the buyer is willing to buy the NFTs
     * @param _quantity     Number of tokens the buyer is willing to buy. 1 if the NFT is ERC721 standard
     */
    function bid(
        address[] memory _nftContract,
        uint256[] memory _tokenId,
        uint256[] memory _price,
        uint256[] memory _quantity
    ) public payable nonReentrant {
        require(
            _nftContract.length == _tokenId.length &&
                _nftContract.length == _price.length &&
                _nftContract.length == _quantity.length,
            "ARRAY_LENGTHS_MISMATCH"
        );
        uint256 totalPrice;

        for (uint256 i = 0; i < _nftContract.length; i++) {
            address nftContract = _nftContract[i];
            uint256 tokenId = _tokenId[i];
            uint256 price = _price[i];
            uint256 quantity = _quantity[i];

            if (!tokenIdExists(nftContract, tokenId)) {
                tokenIdsInCollection[nftContract].push(tokenId);
            }

            bids[nftContract][tokenId].push(
                Bid({
                    exists: true,
                    buyer: msg.sender,
                    price: price,
                    quantity: quantity,
                    timestamp: block.timestamp
                })
            );

            emit BidCreated({
                nft: nftContract,
                tokenID: tokenId,
                buyer: msg.sender,
                price: price,
                quantity: quantity
            });

            totalPrice += price * quantity;
            emit BidPayment(
                false,
                msg.sender,
                Bid({
                    exists: true,
                    buyer: msg.sender,
                    price: price,
                    quantity: quantity,
                    timestamp: block.timestamp
                })
            );
        }

        require(msg.value >= totalPrice, "REVERT_INSUFFICIENT_ETHER");
        escrow[msg.sender] += (totalPrice);
        payable(msg.sender).transfer(msg.value - totalPrice);
    }

    /**
     * @notice Cancels ask(s) that the seller previously created
     * @param _nftContract      An array of ERC-721 and / or ERC-1155 addresses
     * @param _tokenId          Token Ids of the NFTs msg.sender wishes to cancel the asks on
     * @param _askIndex         Index of this particular ask in the asks array
     */
    function cancelAsk(
        address[] memory _nftContract,
        uint256[] memory _tokenId,
        uint256[] memory _askIndex
    ) public {
        for (uint256 i = 0; i < _nftContract.length; i++) {
            address nftContract = _nftContract[i];
            uint256 tokenId = _tokenId[i];
            uint256 askIndex = _askIndex[i];
            address seller = asks[nftContract][tokenId][askIndex].seller;
            uint256 price = asks[nftContract][tokenId][askIndex].price;
            uint256 quantity = asks[nftContract][tokenId][askIndex].quantity;
            require(seller == msg.sender, "REVERT_NOT_A_CREATOR_OF_ASK");
            bool success = safeTransferFrom_(
                nftContract,
                tokenId,
                address(this),
                msg.sender,
                quantity,
                new bytes(0)
            );
            require(success, "TRANSFER_FAILED");

            delete asks[nftContract][tokenId][askIndex];

            emit AskDeleted({
                nft: nftContract,
                tokenID: tokenId,
                seller: seller,
                price: price
            });
        }
    }

    /**
     * @notice Cancels bid(s) that the msg.sender previously created
     * @param _nftContract      An array of ERC-721 and / or ERC-1155 addresses
     * @param _tokenId          Token Ids of the NFTs msg.sender wishes to cancel the bids on
     * @param _bidIndex         Index of this particular bid in the bids array
     */
    function cancelBid(
        address[] memory _nftContract,
        uint256[] memory _tokenId,
        uint256[] memory _bidIndex
    ) public nonReentrant {
        for (uint256 i = 0; i < _nftContract.length; i++) {
            address nftAddress = _nftContract[i];
            uint256 tokenId = _tokenId[i];
            uint256 bidIndex = _bidIndex[i];
            address buyer = bids[nftAddress][tokenId][bidIndex].buyer;
            uint256 price = bids[nftAddress][tokenId][bidIndex].price;
            uint256 quantity = bids[nftAddress][tokenId][bidIndex].quantity;
            require(buyer == msg.sender, "REVERT_NOT_A_CREATOR_OF_BID");

            escrow[msg.sender] -= (price * quantity);
            emit BidPayment(
                true,
                msg.sender,
                bids[nftAddress][tokenId][bidIndex]
            );

            delete bids[nftAddress][tokenId][bidIndex];

            emit BidDeleted({
                nft: nftAddress,
                tokenID: tokenId,
                buyer: buyer,
                price: price
            });
            payable(msg.sender).transfer(price * quantity);
        }
    }

    /**
     * @notice Seller placed ask(s), you (buyer) are fine with the terms. You accept
     * their ask by sending the required msg.value and indicating the id of the
     * token(s) you are purchasing.
     *
     * @param _nftContract      An array of ERC-721 and / or ERC-1155 addresses
     * @param _tokenId          Token Ids of the NFTs msg.sender wishes to accept the asks on
     * @param _quantity         Number of tokens the buyer is willing to buy. 1 if the NFT is ERC721 standard
     * @param _askIndex         Index of this particular ask in the asks array
     */
    function acceptAsk(
        address[] memory _nftContract,
        uint256[] memory _tokenId,
        uint256[] memory _quantity,
        uint256[] memory _askIndex
    ) public payable nonReentrant {
        require(
            _nftContract.length == _tokenId.length &&
                _nftContract.length == _askIndex.length &&
                _nftContract.length == _quantity.length,
            "ARRAY_LENGTHS_MISMATCH"
        );
        uint256 totalPrice;
        for (uint256 i = 0; i < _nftContract.length; i++) {
            address nftContract = _nftContract[i];
            uint256 tokenId = _tokenId[i];
            uint256 askIndex = _askIndex[i];
            uint256 quantity = _quantity[i];
            bool exists = asks[nftContract][tokenId][askIndex].exists;
            address seller = asks[nftContract][tokenId][askIndex].seller;
            uint256 price = asks[nftContract][tokenId][askIndex].price;

            require(exists, "REVERT_ASK_DOES_NOT_EXIST");
            require(seller != msg.sender, "REVERT_CANT_ACCEPT_OWN_ASK");
            require(
                quantity <= asks[nftContract][tokenId][askIndex].quantity,
                "QUANTITY_EXCEEDS_ASK"
            );

            totalPrice += (price * quantity);

            uint256 creatorRoyalty = payRoyalty(
                nftContract,
                price,
                quantity,
                tokenId
            );

            allowedToWithdraw[beneficiary] += feeContract._collectMarketFee(
                seller,
                price * quantity
            );

            emit AskPayment(true, seller, asks[nftContract][tokenId][askIndex]);

            // Quantity will reduce in case of ERC1155 tokens and deleted in case of ERC721 tokens
            if (quantity < asks[nftContract][tokenId][askIndex].quantity) {
                asks[nftContract][tokenId][askIndex].quantity -= quantity;
            } else {
                delete asks[nftContract][tokenId][askIndex];
            }
            addressToCollection[nftContract].volumeTraded += (price * quantity);
            lastTradedPrice[nftContract][tokenId] = price;
            SaleLog memory tempLog;
            tempLog.price = price;
            tempLog.timestamp = block.timestamp;
            tempLog.seller = seller;
            tempLog.buyer = msg.sender;
            priceHistory[nftContract][tokenId].push(tempLog);
            bool success = safeTransferFrom_(
                nftContract,
                tokenId,
                address(this),
                msg.sender,
                quantity,
                new bytes(0)
            );
            require(success, "REVERT_NFT_NOT_SENT");
            emit AskAccepted({
                nft: nftContract,
                tokenID: tokenId,
                price: price,
                quantity: quantity,
                buyer: msg.sender
            });
            emit AskPayment(
                false,
                msg.sender,
                asks[nftContract][tokenId][askIndex]
            );
            payable(seller).transfer(
                (price * quantity) -
                    feeContract._collectMarketFee(seller, price * quantity) -
                    creatorRoyalty
            );
        }
        require(msg.value >= totalPrice, "REVERT_INSUFFICIENT_ETHER");
        payable(msg.sender).transfer(msg.value - totalPrice);
    }

    /**
     * @notice You are the owner of the NFTs, someone submitted the bids on them.
     * You accept one or more of these bids.
     *
     * @param _nftContract      An array of ERC-721 and / or ERC-1155 addresses
     * @param _tokenId          Token Ids of the NFTs msg.sender wishes to accept the bids on
     * @param _quantity         Number of tokens the buyer is willing to buy. 1 if the NFT is ERC721 standard
     * @param _bidIndex         Index of this particular bid in the bids array
     */
    function acceptBid(
        address[] memory _nftContract,
        uint256[] memory _tokenId,
        uint256[] memory _quantity,
        uint256[] memory _bidIndex
    ) public nonReentrant {
        require(
            _nftContract.length == _tokenId.length &&
                _nftContract.length == _bidIndex.length &&
                _nftContract.length == _quantity.length,
            "ARRAY_LENGTHS_MISMATCH"
        );

        for (uint256 i = 0; i < _nftContract.length; i++) {
            require(
                quantityOf(_nftContract[i], msg.sender, _tokenId[i]) > 0,
                "REVERT_NOT_OWNER_OF_TOKEN_ID"
            );

            address nftContract = _nftContract[i];
            uint256 tokenId = _tokenId[i];
            uint256 bidIndex = _bidIndex[i];
            uint256 quantity = _quantity[i];
            uint256 price = bids[nftContract][tokenId][bidIndex].price;
            address buyer = bids[nftContract][tokenId][bidIndex].buyer;

            require(isApproved(_nftContract[i]), "NOT_APPROVED_FOR_TRANSFER");

            uint256 creatorRoyalty = payRoyalty(
                nftContract,
                price,
                quantity,
                tokenId
            );

            allowedToWithdraw[beneficiary] += feeContract._collectMarketFee(
                msg.sender,
                price * quantity
            );

            emit BidPayment(
                true,
                msg.sender,
                bids[nftContract][tokenId][bidIndex]
            );
            // delete ask if ERC721
            if (!addressToCollection[nftContract].isFractional) {
                for (
                    uint256 j = 0;
                    j < asks[nftContract][tokenId].length;
                    j++
                ) {
                    Ask memory _ask = asks[nftContract][tokenId][j];
                    if (_ask.seller == msg.sender) {
                        delete asks[nftContract][tokenId][j];
                    }
                }
            }
            Bid memory tempBid = bids[nftContract][tokenId][bidIndex]; // For event emit
            // Quantity will reduce in case of ERC1155 tokens and deleted in case of ERC721 tokens
            if (quantity < bids[nftContract][tokenId][bidIndex].quantity) {
                bids[nftContract][tokenId][bidIndex].quantity -= quantity;
            } else {
                delete bids[nftContract][tokenId][bidIndex];
            }
            addressToCollection[nftContract].volumeTraded += price * quantity;
            lastTradedPrice[nftContract][tokenId] = price;
            SaleLog memory tempLog;
            tempLog.price = price;
            tempLog.timestamp = block.timestamp;
            tempLog.seller = msg.sender;
            tempLog.buyer = buyer;
            priceHistory[nftContract][tokenId].push(tempLog);

            uint256 balancePayable = price * quantity;
            require(escrow[buyer] >= balancePayable, "LOW_BUYER_BALANCE");
            escrow[buyer] -= balancePayable;
            bool success = safeTransferFrom_(
                nftContract,
                tokenId,
                msg.sender,
                buyer,
                quantity,
                new bytes(0)
            );
            require(success, "REVERT_NFT_NOT_SENT");

            emit BidPayment(false, buyer, tempBid);

            emit BidAccepted({
                nft: nftContract,
                tokenID: tokenId,
                price: price,
                quantity: quantity,
                seller: msg.sender
            });

            payable(msg.sender).transfer(
                (price * quantity) -
                    feeContract._collectMarketFee(
                        msg.sender,
                        price * quantity
                    ) -
                    creatorRoyalty
            );
        }
    }

    /**
     * @notice Withdrawal of accumulated funds from escrow account
     * @param amount    Amount to be withdrawn
     */
    function withdraw(int256 amount) public nonReentrant {
        // Enter amount = -1 for MAX withdrawal
        uint256 transferAmount;
        if (amount == -1) {
            transferAmount = allowedToWithdraw[msg.sender];
        } else {
            transferAmount = uint256(amount);
        }
        require(
            transferAmount <= allowedToWithdraw[msg.sender],
            "AMOUNT_EXCEEDS_BALANCE"
        );
        allowedToWithdraw[msg.sender] -= transferAmount;
        payable(address(msg.sender)).transfer(transferAmount);

        emit Withdrawal(msg.sender, transferAmount);
    }

    /**
     * @notice Change the Collection creator and Fee contract address
     * @dev Can only be called by the owner of the marketplace
     * @param _newCreatorContract   Address of the new creatorContract
     * @param _newFeeContract   Address of the new feeContract
     */
    function changeCreatorAndFeeContract(
        address _newCreatorContract,
        address _newFeeContract,
        address payable _beneficiary
    ) public onlyOwner {
        creatorContractAddress = _newCreatorContract;
        feeContract = IMarketPlaceFeeContract(_newFeeContract);
        beneficiary = _beneficiary;
    }

    /**
     * @notice Rejects a Creator Royalty payment request
     * @dev Can only be called by the owner of the marketplace
     * @param _nftContract Address of the NFT collection
     * @param _newOwner Address of the new owner of the collection
     */
    function changeCollectionOwner(address _nftContract, address _newOwner)
        public
        onlyOwner
    {
        addressToCollection[_nftContract].createdBy = _newOwner;
    }

    /**
     * @notice Returns the floorPrice of a collection
     * @param nftContract   Address of the collection
     * @return floor price of a collection
     */
    function floorPrice(address nftContract) public view returns (uint256) {
        uint256 _floorPrice;
        uint256[] memory _tokenIds = tokenIdsInCollection[nftContract];
        if (_tokenIds.length == 0) {
            return 0;
        } else {
            _floorPrice = asks[nftContract][_tokenIds[0]][0].price;
        }
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            Ask[] memory askArray = asks[nftContract][_tokenIds[i]];
            for (uint256 j = 0; j < askArray.length; j++) {
                if (askArray[j].price < _floorPrice || _floorPrice == 0) {
                    _floorPrice = askArray[j].price;
                }
            }
        }
        return _floorPrice;
    }

    /**
     * @notice Returns the tokenIds in a collection
     * @param nftContract   Address of the collection
     * @return tokenIds array of tokenIds
     */
    function fetchTokensInCollection(address nftContract)
        public
        view
        returns (uint256[] memory tokenIds)
    {
        return tokenIdsInCollection[nftContract];
    }

    // PUBLIC FUNCTIONS

    /**
     * @notice Returns the list of collections in the marketplace
     * @return collectionsList An array of collections
     */
    function fetchCollectionsList()
        public
        view
        returns (address[] memory collectionsList)
    {
        return collections;
    }

    /**
     * @notice Returns all NFTs held by the user
     * @param _user User address whose NFTs are requested
     * @return userNFTAddresses userNFTIds - An array of collections and the corresponding tokenIds owned by the user
     */
    function fetchUserNFTs(address _user)
        public
        view
        returns (address[] memory userNFTAddresses, uint256[] memory userNFTIds)
    {
        uint256 counter;

        for (uint256 i = 0; i < collections.length; i++) {
            if (collections[i] == address(0)) {
                continue;
            }
            address tempCollectionAddress = collections[i];
            for (
                uint256 j = 0;
                j < tokenIdsInCollection[tempCollectionAddress].length;
                j++
            ) {
                if (addressToCollection[tempCollectionAddress].isFractional) {
                    if (
                        IERC1155(tempCollectionAddress).balanceOf(
                            _user,
                            tokenIdsInCollection[tempCollectionAddress][j]
                        ) > 0
                    ) {
                        userNFTAddresses[counter] = tempCollectionAddress;
                        userNFTIds[counter] = tokenIdsInCollection[
                            tempCollectionAddress
                        ][j];
                        counter++;
                    }
                } else {
                    if (
                        ERC721(tempCollectionAddress).ownerOf(
                            tokenIdsInCollection[tempCollectionAddress][j]
                        ) == msg.sender
                    ) {
                        userNFTAddresses[counter] = tempCollectionAddress;
                        userNFTIds[counter] = tokenIdsInCollection[
                            tempCollectionAddress
                        ][j];
                        counter++;
                    }
                }
            }
        }
    }

    /**
     * @notice Returns all Asks and Bids for a token
     * @param nftContract nft contract address whose Asks and Bids are requested
     * @param tokenId token id whose Asks and Bids are requested
     * @return Asks Bids - Asks and Bids for a token id
     */
    function fetchTokenAsksAndBids(address nftContract, uint256 tokenId)
        public
        view
        returns (Ask[] memory Asks, Bid[] memory Bids)
    {
        return (asks[nftContract][tokenId], bids[nftContract][tokenId]);
    }

    /**
     * @notice Returns the lowest ask for a token
     * @param nftContract     NFT address
     * @param tokenId         id of the token
     * @return Lowest ask and corresponding quantity
     */
    function lowestAsk(address nftContract, uint256 tokenId)
        public
        view
        returns (uint256, uint256)
    {
        uint256 lowestAskPrice;
        uint256 correspondingQuantity;
        Ask[] memory currentAsk = asks[nftContract][tokenId];
        if (currentAsk.length == 0) {
            return (0, 0);
        } else {
            lowestAskPrice = currentAsk[0].price;
            correspondingQuantity = currentAsk[0].quantity;
        }
        for (uint256 i = 0; i < currentAsk.length; i++) {
            if (currentAsk[i].price < lowestAskPrice || lowestAskPrice == 0) {
                lowestAskPrice = currentAsk[i].price;
                correspondingQuantity = currentAsk[i].quantity;
            }
            if (currentAsk[i].price == lowestAskPrice || lowestAskPrice == 0) {
                correspondingQuantity += currentAsk[i].quantity;
            }
        }
        return (lowestAskPrice, correspondingQuantity);
    }

    /**
     * @notice Returns the highest bid for a token
     * @param nftContract     NFT address
     * @param tokenId         id of the token
     * @return Highest bid and corresponding quantity
     */
    function highestBid(address nftContract, uint256 tokenId)
        public
        view
        returns (uint256, uint256)
    {
        uint256 highestBidPrice;
        uint256 correspondingQuantity;
        Bid[] memory currentBid = bids[nftContract][tokenId];
        if (currentBid.length == 0) {
            return (0, 0);
        } else {
            highestBidPrice = currentBid[0].price;
            correspondingQuantity = currentBid[0].quantity;
        }
        for (uint256 i = 0; i < currentBid.length; i++) {
            if (currentBid[i].price > highestBidPrice || highestBidPrice == 0) {
                highestBidPrice = currentBid[i].price;
                correspondingQuantity = currentBid[i].quantity;
            }
            if (
                currentBid[i].price == highestBidPrice || highestBidPrice == 0
            ) {
                correspondingQuantity += currentBid[i].quantity;
            }
        }
        return (highestBidPrice, correspondingQuantity);
    }

    /**
     * @notice Returns the creators for a collection
     * @param nftContract     NFT address
     * @return creators array
     */
    function fetchCreators(address nftContract)
        public
        view
        returns (Creator[] memory creators)
    {
        return creatorFees[nftContract];
    }

    /**
     * @notice Returns if the marketplace is approved by the msg.sender for transfers
     * @param nftContract   Address of ERC721 or ERC1155 contract
     * @return approved True if approved and False if not
     */
    function isApproved(address nftContract)
        public
        view
        returns (bool approved)
    {
        return IERC721(nftContract).isApprovedForAll(msg.sender, address(this));
    }

    /**
     * @notice Returns the price history of the tokenId
     * @param _nftContract  Address of the collection
     * @param _tokenId      Token Id of the requested token
     * @return Array of price history for the token
     */
    function fetchPriceHistory(address _nftContract, uint256 _tokenId)
        public
        view
        returns (SaleLog[] memory)
    {
        return priceHistory[_nftContract][_tokenId];
    }

    // INTERNAL FUNCTIONS

    /**
     * @notice Transfers the NFT tokenID from to
     * @dev safeTransferFrom_ name to avoid collision with the interface signature definitions. The reason it is implemented the way it is,
     *  is because some NFT contracts implement both the 721 and 1155 standard at the same time. Sometimes, 721 or 1155 function does not work.
     *  So instead of relying on the user's input, or asking the contract what interface it implements, it is best to just make a good assumption
     *  about what NFT type it is (here we guess it is 721 first), and if that fails, we use the 1155 function to tranfer the NFT.
     * @param nftContract    NFT address
     * @param from           Source address
     * @param to             Target address
     * @param tokenId        ID of the token type
     * @param quantity       Quantity of tokens
     * @param data           Additional data with no specified format, MUST be sent unaltered in call to `onERC1155Received` on `_to`
     */
    function safeTransferFrom_(
        address nftContract,
        uint256 tokenId,
        address from,
        address to,
        uint256 quantity,
        bytes memory data
    ) internal returns (bool) {
        // most are 721s, so we assume that that is what the NFT type is
        try IERC721(nftContract).safeTransferFrom(from, to, tokenId, data) {
            return true;
            // on fail, use 1155s format
        } catch (bytes memory) {
            try
                IERC1155(nftContract).safeTransferFrom(
                    from,
                    to,
                    tokenId,
                    quantity,
                    data
                )
            {
                return true;
            } catch (bytes memory) {
                return false;
            }
        }
    }

    /**
     * @notice Determines if potentialOwner is in fact an owner of at least 1 qty of NFT token ID.
     * @param nftContract     NFT address
     * @param potentialOwner  suspected owner of the NFT token ID
     * @param tokenId         id of the token
     * @return quantity of held token, possibly zero
     */
    function quantityOf(
        address nftContract,
        address potentialOwner,
        uint256 tokenId
    ) internal view returns (uint256) {
        try IERC721(nftContract).ownerOf(tokenId) returns (address owner) {
            if (owner == potentialOwner) {
                return 1;
            } else {
                return 0;
            }
        } catch (bytes memory) {
            try
                IERC1155(nftContract).balanceOf(potentialOwner, tokenId)
            returns (uint256 amount) {
                return amount;
            } catch (bytes memory) {
                return 0;
            }
        }
    }

    // PRIVATE FUNCTIONS

    /**
     * @notice Adds creator royalties to creators of an NFT collection
     * @param _nftContract  NFT address
     * @param _creators     Array of creator addresses that share the royalty
     * @param _percentages  Array of percentages corresponding to the creators above
     */
    function addCreatorFees(
        address _nftContract,
        address payable[] memory _creators,
        uint16[] memory _percentages
    ) private {
        for (uint256 j = 0; j < _creators.length; j++) {
            Creator memory _creatorFees;
            _creatorFees.creator = _creators[j];
            _creatorFees.shareInPercentage = _percentages[j];
            creatorFees[_nftContract].push(_creatorFees);
        }
    }

    /**
     * @notice Calculates royalty fees for creators of a collection during acceptAsk or acceptBid operations
     * @param _nftContract  NFT address
     * @param _price        Price of the token
     * @param _quantity     Quantity of the token
     * @param _tokenId      Token Id of the NFT
     * @return Royalty fees calculated
     */
    function payRoyalty(
        address _nftContract,
        uint256 _price,
        uint256 _quantity,
        uint256 _tokenId
    ) private returns (uint256) {
        uint256 creatorRoyalty;
        if (addressToCollection[_nftContract].creatorRoyaltyInPercentage > 0) {
            for (uint256 j = 0; j < creatorFees[_nftContract].length; j++) {
                uint256 total = _price * _quantity;
                uint256 share = (((total *
                    addressToCollection[_nftContract]
                        .creatorRoyaltyInPercentage) / HUNDRED) *
                    creatorFees[_nftContract][j].shareInPercentage) / HUNDRED;
                allowedToWithdraw[
                    creatorFees[_nftContract][j].creator
                ] += share;
                creatorRoyalty += share;
                emit RoyaltyPayment(
                    creatorFees[_nftContract][j].creator,
                    share,
                    _nftContract,
                    _tokenId
                );
            }
        }
        return creatorRoyalty;
    }

    /**
     * @notice Checks if a tokenId exists within a collection
     * @param _nftContract  NFT contract address
     * @param _tokenId      Token Id of the NFT
     * @return True if exists and False if not
     */
    function tokenIdExists(address _nftContract, uint256 _tokenId)
        private
        view
        returns (bool)
    {
        for (
            uint256 i = 0;
            i < tokenIdsInCollection[_nftContract].length;
            i++
        ) {
            if (tokenIdsInCollection[_nftContract][i] == _tokenId) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Deletes a collection from the contract
     * @param _nftContract  NFT contract address
     */
    function deleteCollection(address _nftContract) external onlyOwner {
        Collection memory _tempCollection;
        addressToCollection[_nftContract] = _tempCollection;
        for (uint256 i = 0; i < collections.length; i++) {
            if (collections[i] == _nftContract) {
                delete collections[i];
                break;
            }
        }
    }
}
