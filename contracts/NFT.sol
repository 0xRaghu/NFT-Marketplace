// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./libraries/CustomOwnable.sol";

contract NFT is ERC721Enumerable, CustomOwnable {
    using Strings for uint256;
    bool public publicMinting;

    string public baseExtension = ".json";
    uint256 public cost = 0 ether;
    uint256 public maxSupply;
    uint256 public maxMintAmount;
    uint256 public timeDeployed;
    uint256 public allowMintingAfter = 0;
    bool public isPaused = false;
    bool public isRevealed = true;
    uint256 public maxMintsPerAccount;
    mapping(uint256 => string) public tokenURIs;

    event PublicMintingEnabled(
        uint256 _revealTime,
        uint256 _maxSupply,
        uint256 _maxMintAmount,
        uint256 _cost,
        uint256 _maxMintsPerAccount
    );

    event Withdrawal(address payee, uint256 amount);

    /**
     * @notice Initiates an NFT collection
     * @param _name     Name of the collection
     * @param _symbol   Symbol of the collection
     * @param _owner    Address of the contract owner
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC721(_name, _symbol) CustomOwnable(_owner) {
        timeDeployed = block.timestamp;
    }

    /**
     * @notice Enables Public minting with time and max mint conditions
     * @param _revealTime           Time at which the URI for tokens are available to view
     * @param _revealed             True if the URI is revealed and False if not
     * @param _maxSupply            Maximum supply that can be minted
     * @param _maxMintAmount        Maximum mints per account per mint
     * @param _cost                 Cost of minting a token
     * @param _maxMintsPerAccount   Maximum number of mints per account
     */
    function enablePublicMinting(
        uint256 _revealTime,
        bool _revealed,
        uint256 _maxSupply,
        uint256 _maxMintAmount,
        uint256 _cost,
        uint256 _maxMintsPerAccount
    ) public onlyOwner {
        publicMinting = true;
        if (_revealTime > block.timestamp) {
            allowMintingAfter = _revealTime - block.timestamp;
        }
        maxSupply = _maxSupply;
        maxMintAmount = _maxMintAmount;
        cost = _cost;
        isRevealed = _revealed;
        maxMintsPerAccount = _maxMintsPerAccount;
        emit PublicMintingEnabled(
            _revealTime,
            _maxSupply,
            _maxMintAmount,
            _cost,
            _maxMintsPerAccount
        );
    }

    /**
     * @notice Mints a new token for the msg.sender
     * @param uri       Metadata URI of the new token
     * @param _owner    Address the token should be minted to
     * @return total supply of the tokens
     */
    function createToken(string memory uri, address _owner)
        public
        onlyOwner
        returns (uint256)
    {
        uint256 supply = totalSupply();
        _safeMint(_owner, supply + 1);
        tokenURIs[supply + 1] = uri;
        return totalSupply();
    }

    /**
     * @notice Mints multiple new tokens for the msg.sender
     * @param uris          Metadata URIs of the new token
     * @param _mintAmount   Number of tokens to be minted
     */
    function batchCreateTokens(uint256 _mintAmount, string[] memory uris)
        public
        onlyOwner
    {
        uint256 supply = totalSupply();
        require(!isPaused, "CONTRACT_PAUSED");
        require(_mintAmount > 0, "INVALID_MINT_AMOUNT");
        // require(supply + _mintAmount <= maxSupply, "EXCEEDS_MAX_SUPPLY");
        require(_mintAmount == uris.length, "URI_COUNT_MISMATCH");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
            tokenURIs[supply + i] = uris[i - 1];
        }
    }

    // PUBLIC FUNCTIONS

    /**
     * @notice Mints a new token for the msg.sender
     * @param _mintAmount   Number of tokens to be minted
     * @param uris          Metadata URIs of the new token
     */
    function mint(uint256 _mintAmount, string[] memory uris) public payable {
        require(publicMinting, "PUBLIC_MINTING_NOT_ENABLED");
        require(
            block.timestamp >= timeDeployed + allowMintingAfter,
            "MINTING_NOT_ALLOWED_YET"
        );

        require(
            balanceOf(msg.sender) < maxMintsPerAccount,
            "MAX_MINTS_PER_ACCOUNT_EXCEEDED"
        );

        uint256 supply = totalSupply();
        require(!isPaused, "CONTRACT_PAUSED");
        require(
            _mintAmount > 0 && _mintAmount <= maxMintAmount,
            "INVALID_MINT_AMOUNT"
        );
        require(supply + _mintAmount <= maxSupply, "EXCEEDS_MAX_SUPPLY");
        require(_mintAmount == uris.length, "URI_COUNT_MISMATCH");

        if (msg.sender != owner()) {
            require(
                msg.value >= cost * _mintAmount,
                "MSG_VALUE_LESS_THEN_COST"
            );
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
            tokenURIs[supply + i] = uris[i];
        }
    }

    /**
     * @notice Returns the token ids held by a user
     * @param _owner Wallet to be tested for
     * @return token Ids held by the user
     */
    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    /**
     * @notice Returns the token URI of a token
     * @param tokenId Token ID for which URI is to be revealed
     * @return tokenId - URI of the token
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "URI_QUERY_FOR_NON_EXISTENT_TOKEN");

        return tokenURIs[tokenId];
    }

    /**
     * @notice Revelas the number of seconds until public minting goes live
     * @return Number of seconds until public minting starts
     */
    function getSecondsUntilMinting() public view returns (uint256) {
        if (block.timestamp < timeDeployed + allowMintingAfter) {
            return (timeDeployed + allowMintingAfter) - block.timestamp;
        } else {
            return 0;
        }
    }

    // ONLY OWNER FUNCTIONS

    /**
     * @notice Sets reveal status for the collection
     * @param _state New state of reveal
     */
    function setIsRevealed(bool _state) public onlyOwner {
        isRevealed = _state;
    }

    /**
     * @notice Sets cost of minting new token
     * @param _newCost New cost of minting
     */
    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    /**
     * @notice Sets maximum mint amount
     * @param _newmaxMintAmount New maximum mint amount
     */
    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    /**
     * @notice Sets the paused status of the collection
     * @param _state New paused state of the collection
     */
    function setIsPaused(bool _state) public onlyOwner {
        isPaused = _state;
    }

    /**
     * @notice enables admin withdrawal of funds from the protocol
     */
    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
        require(address(this).balance == 0, "TRANSFER_FAILED");
        emit Withdrawal(msg.sender, balance);
    }
}
