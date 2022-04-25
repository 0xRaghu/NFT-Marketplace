// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOwnableNFT {
    /**
     * @notice Returns the owner of an NFT Collection
     * @return address of the owner
     */
    function owner() external view returns (address);
}
