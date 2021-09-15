
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDiaOracle {
	
	function changeOwner(address newOwner) external;
    
	function updateCoinInfo(string calldata name, string calldata symbol, uint256 newPrice, uint256 newSupply, uint256 newTimestamp) external;
    
	function getValue(string memory key) external view returns (uint128, uint128);
}