// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMarketPlaceFeeContract.sol";

contract MarketplaceFeeContract is IMarketPlaceFeeContract, Ownable {
    using Address for address payable;
    // 3% in basis points
    uint16 public fee;
    uint16 public constant HUNDRED_PERCENT = 10000;

    event FeeChanged(uint16 _oldFee, uint16 _newFee);

    /**
     * @notice Initiates the contract with beneficiary address
     * @param _fee  Fee percentage
     */
    constructor(uint16 _fee) {
        // Fee should be raised to 10^2 ex., 3% => 300
        fee = _fee;
    }

    /**
     * @notice Collects and pays marketplace fees for a transaction
     * @param _user         Address of the user performing the transaction
     * @param _totalPrice   Total transaction value
     * @return transaction value left after fee deduction
     */
    function _collectMarketFee(address _user, uint256 _totalPrice)
        public
        view
        returns (uint256)
    {
        _user; // To silence warnings
        // SafeMath operations are embedded into solidity v0.8.10
        uint256 cut = (_totalPrice * fee) / HUNDRED_PERCENT;
        return cut;
    }

    /**
     * @notice Changes the fee percentage charged by marketplace
     * @dev Can only be called by the owner of the contract
     * @param _newFee       New Fee percentage
     */
    function changeFee(uint16 _newFee) public onlyOwner {
        require(_newFee < HUNDRED_PERCENT, "NEW_FEE_SHOULD_BE_LT_100_PERCENT");
        uint16 _oldFee = fee;
        fee = _newFee;
        emit FeeChanged(_oldFee, _newFee);
    }

    /**
     * @notice Returns the market fees for a user
     * @param _user         Address of the user performing the transaction
     * @return Fee percentage
     */
    function _getMarketFee(address _user) public view returns (uint256) {
        _user; // To silence warnings
        return fee;
    }
}
