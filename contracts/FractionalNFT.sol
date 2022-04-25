// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./libraries/CustomOwnable.sol";

contract FractionalNFT is ERC1155, CustomOwnable {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;

    // NFT name
    string public name;

    // NFT symbol
    string public symbol;

    // Mapping from token ID to token supply
    mapping(uint256 => uint256) private tokenSupply;

    // Mapping from token ID to token existence
    mapping(uint256 => bool) private exists;

    // Mapping from token ID to token URI
    mapping(uint256 => string) private tokenURI;

    /**
     * @notice Initiates a Fractional NFT collection
     * @param _name     Name of the collection
     * @param _symbol   Symbol of the collection
     * @param _owner    Address of the contract owner
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC1155("") CustomOwnable(_owner) {
        name = _name;
        symbol = _symbol;
    }

    /**
     * @notice Mints a new token in the collection
     * @param quantity  Quantity of tokens to be created
     * @param _uri      Metadata URI of the new token
     * @param _owner    Address the token should be minted to
     * @return token id of the new token created
     */
    function createToken(
        uint256 quantity,
        string memory _uri,
        address _owner
    ) public onlyOwner returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        require(!exists[newItemId], "INVALID_ID");

        super._mint(_owner, newItemId, quantity, new bytes(0));
        tokenURI[newItemId] = _uri;
        tokenSupply[newItemId] += quantity;
        return newItemId;
    }

    /**
     * @notice Mints multiple new tokens in the collection
     * @param quantities    Quantities corresponding to the new tokens
     * @param uris          Metadata URIs of the new tokens
     * @return token ids of the new tokens created
     */
    function batchCreateTokens(
        uint256[] memory quantities,
        string[] memory uris
    ) public onlyOwner returns (uint256[] memory) {
        uint256[] memory ids;
        for (uint256 i = 0; i < quantities.length; i++) {
            _tokenIds.increment();
            ids[i] = _tokenIds.current();
        }

        require(ids.length == quantities.length, "MISMATCHED_ARRAY_LENGTHS");

        super._mintBatch(msg.sender, ids, quantities, new bytes(0));

        for (uint256 i = 0; i < ids.length; i++) {
            tokenSupply[ids[i]] += quantities[i];
            tokenURI[ids[i]] = uris[i];
        }
        return ids;
    }

    /**
     * @notice Returns the URI of a token given its ID
     * @param id ID of the token to query
     * @return uri of the token or an empty string if it does not exist
     */
    function uri(uint256 id) public view override returns (string memory) {
        require(exists[id], "URI_QUERY_FOR_NON_EXISTENT_TOKEN");

        return tokenURI[id];
    }

    /**
     * @notice Returns the total quantity for a token ID
     * @param id ID of the token to query
     * @return amount of token in existence
     */
    function totalSupply(uint256 id) public view returns (uint256) {
        return tokenSupply[id];
    }
}
