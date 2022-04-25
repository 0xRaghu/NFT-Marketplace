// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./NFT.sol";
import "./FractionalNFT.sol";
import "./NFTMarket.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CreateCollection is Ownable {
    address public marketplaceAddress;

    event MarketPlaceAddressChanged(address _oldAddress, address _newAddress);
    event CollectionCreated(address _newCollection);

    /**
     * @notice Creates an ERC721 and / or an ERC1155 NFT Collection
     * @param _name                         Name of the NFT Contract
     * @param _symbol                       Symbol of the NFT Contract
     * @param _description                  Description of the NFT Contract
     * @param _collectionSlug               URL Slug of the NFT Contract
     * @param _isFractional                 True if the contract is ERC1155 compatible and False if ERC721
     * @param _creatorRoyaltyInPercentage   Creator Royalty in percentage scaled to 10^2
     * @param _creators                     Array of creator addresses that share the royalty
     * @param _percentages                  Array of percentages corresponding to the creators above
     */
    function createCollection(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _collectionSlug,
        bool _isFractional,
        uint16 _creatorRoyaltyInPercentage,
        address payable[] memory _creators,
        uint16[] memory _percentages
    ) public returns (address) {
        require(
            marketplaceAddress != address(0),
            "INVALID_MARKETPLACE_ADDRESS"
        );
        address newCollection;
        // Creates a new ERC1155 collection if _isFractional is true and ERC721 otherwise
        if (_isFractional) {
            newCollection = address(
                new FractionalNFT(_name, _symbol, msg.sender)
            );
        } else {
            newCollection = address(new NFT(_name, _symbol, msg.sender));
        }
        // calls createCollection function in the NFT marketplace contract
        NFTMarket(marketplaceAddress).createCollection(
            newCollection,
            _name,
            _symbol,
            _description,
            _collectionSlug,
            _isFractional,
            _creatorRoyaltyInPercentage,
            _creators,
            _percentages,
            msg.sender
        );
        emit CollectionCreated(newCollection);
        return newCollection;
    }

    /**
     * @notice Changes the address of marketplace
     * @dev Can only be called by the owner of the contract
     * @param _newMarketplace   Address of the new marketplace contract
     */
    function changeMarketplaceAddress(address _newMarketplace)
        public
        onlyOwner
    {
        address _oldAddress = marketplaceAddress;
        marketplaceAddress = _newMarketplace;
        emit MarketPlaceAddressChanged(_oldAddress, _newMarketplace);
    }
}
