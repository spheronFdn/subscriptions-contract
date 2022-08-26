//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISubscriptionData {
    function priceData(string memory name) external view returns (uint256);

    function availableParams(string memory name) external view returns (bool);

    function params(uint256 name) external view returns (bool);

    function managerByAddress(address user) external view returns (bool);

    function discountsEnabled() external view returns (bool);

    function stakingManager() external view returns (address);

    function stakedToken() external view returns (address);

    function getUnderlyingPrice(address t) external view returns (uint256, uint256);

    function escrow() external view returns (address);

    function slabs() external view returns (uint256[] memory);

    function discountPercents() external view returns (uint256[] memory);

    function addNewTokens(
        string[] memory s,
        address[] memory t,
        uint128[] memory d,
        bool[] memory isChainLinkFeed_,
        address[] memory priceFeedAddress_,
        uint128[] memory priceFeedPrecision_
    ) external;

    function removeTokens(address[] memory t) external;

    function usdPricePrecision() external returns (uint128);
    
    function changeUsdPrecision(uint128 p) external;

    function acceptedTokens(address token)
        external
        returns (
            string memory symbol,
            uint128 decimals,
            address tokenAddress,
            bool accepted,
            bool isChainLinkFeed,
            address priceFeedAddress,
            uint128 priceFeedPrecision
        );
    function isAcceptedToken(address token) external returns (bool);
}
