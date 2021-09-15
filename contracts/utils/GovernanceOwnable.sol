//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "./MultiOwnable.sol";

contract GovernanceOwnable is MultiOwnable {
    address public governanceAddress;

    modifier onlyGovernanceAddress() {
        require(
            msg.sender == governanceAddress,
            "Caller is not the governance contract"
        );
        _;
    }

    /**
     * @dev GovernanceOwnable constructor sets the governance address
     * @param g address of governance contract
     */
    function setGovernanceAddress(address g) public onlyOwner {
        governanceAddress = g;
    }
}