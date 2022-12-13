//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract MultiOwnable {
    address public owner; // address used to set owners
    address[] public managers;
    mapping(address => bool) public managerByAddress;

    event SetManagers(address[] managers);

    event RemoveManagers(address[] managers);

    event ChangeOwner(address indexed owner);

    modifier onlyManager() {
        require(
            managerByAddress[msg.sender] == true || msg.sender == owner,
            "Only manager and owner can call this function"
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @dev MultiOwnable constructor sets the owner
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Function to set managers
     * @param m list of addresses that are to be added as managers
     */
    function setManagers(address[] memory m) public onlyOwner {
        require(m.length > 0, "At least one manager must be set");
        _setManagers(m);
    }

    /**
     * @dev Function to remove managers
     * @param m list of addresses that are to be removed from managers
     */
    function removeManagers(address[] memory m) public onlyOwner {
        _removeManagers(m);
    }

    /**
     * @dev Function to set managers
     * @param m list of addresses that are to be added  as manager
     */
    function _setManagers(address[] memory m) internal {
        for (uint256 j = 0; j < m.length; j++) {
            require(m[j] != address(0), "Address cannot be zero address");
            if (!managerByAddress[m[j]]) {
                managerByAddress[m[j]] = true;
                managers.push(m[j]);
            }
        }
        emit SetManagers(m);
    }

    /**
     * @dev internal helper function to remove managers
     * @param m list of addresses that are to be removed from managers
     */
    function _removeManagers(address[] memory m) internal {
        require(m.length > 0, "At least one manager must be removed");
        for (uint256 j = 0; j < m.length; j++) {
            if (managerByAddress[m[j]]) {
                for (uint256 k = 0; k < managers.length; k++) {
                    if (managers[k] == m[j]) {
                        managers[k] = managers[managers.length - 1];
                        managers.pop();
                    }
                }
                managerByAddress[m[j]] = false;
            }
        }

        emit RemoveManagers(m);
    }

    /**
     * @dev change owner of the contract
     * @param o address of new owner
     */
    function changeOwner(address o) external onlyOwner {
        require(o != address(0), "New owner cannot be zero address");
        owner = o;
        emit ChangeOwner(o);
    }

    /**
     * @dev get list of all managers
     * @return list of all managers
     */
    function getManagers() external view returns (address[] memory) {
        return managers;
    }

    /**
     * @dev get list of all managers
     * @return list of all managers
     */

    function isManager(address addr) public view returns (bool) {
        if(managerByAddress[addr] == true || addr == owner) {
            return true;
        }
        return false;
    }
}
