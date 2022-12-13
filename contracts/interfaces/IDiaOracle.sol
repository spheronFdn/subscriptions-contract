
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDiaOracle {
	function setValue(string memory key, uint128 value, uint128 timestamp) external;

	function updateOracleUpdaterAddress(address newOracleUpdaterAddress) external;
    
	function getValue(string memory key) external view returns (uint128, uint128);

}