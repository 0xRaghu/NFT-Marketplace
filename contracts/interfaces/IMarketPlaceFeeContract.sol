// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IMarketPlaceFeeContract {
    /**
     * @notice Collects and pays marketplace fees for a transaction
     * @param _user         Address of the user performing the transaction
     * @param _totalPrice   Total transaction value
     * @return transaction value left after fee deduction
     */
    function _collectMarketFee(address _user, uint256 _totalPrice)
        external
        returns (uint256);

    /**
     * @notice Returns the market fees for a user
     * @param _user         Address of the user performing the transaction
     * @return Fee percentage
     */
    function _getMarketFee(address _user) external view returns (uint256);
}
