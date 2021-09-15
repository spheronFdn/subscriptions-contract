//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISubscriptionData{

    function priceData(string memory name) external view returns(uint256);
    function availableParams(string memory name) external view returns(bool);
    function params(uint256 name) external view returns(bool);
    function managerByAddress(address user) external view returns(bool);
    function discountsEnabled() external view returns(bool);
    function stakingManager() external view returns(address);
    function stakedToken() external view returns(address);
    function getUnderlyingPrice() external view returns(uint256);
    function underlying() external view returns(address);
    function escrow() external view returns(address);
    function slabs() external view returns(uint256[] memory);
    function discountPercents() external view returns(uint256[] memory);
}