//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISubscriptionData.sol";
import "hardhat/console.sol";
import "./interfaces/IStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SubscriptionPayments is Ownable {

    ISubscriptionData public subscriptionData;
    //For improved precision
    uint256 constant PRECISION = 10**25;
    uint256 constant PERCENT = 100 * PRECISION;
    //decimal precision
    uint256 constant DECIMAL = 10**18;

    modifier onlyManager() {
        bool isManager = subscriptionData.managerByAddress(msg.sender);
        address owner = owner();
        require(
            isManager || msg.sender == owner,
            "Only manager and owner can call this function"
        );
        _;
    }

    constructor(address d) {
        require(
            d != address(0),
            "ArgoSubscriptionPayments: SubscriptionData contract address can not be zero address"
        );
        subscriptionData = ISubscriptionData(d);
    }

    function chargeUser(
        address u,
        string[] memory p,
        uint256[] memory v
    ) external onlyManager {
        require(
            p.length == v.length,
            "ArgoSubscriptionPayments: unequal length of array"
        );
        uint256 fee = 0;
        for (uint256 i = 0; i < p.length; i++) {

            fee += v[i] * subscriptionData.priceData(p[i]);
        }
        uint256 discount = fee - _calculateDiscount(u, fee);
        uint256 underlying = _calculatePriceInArgo(discount);
        
        IERC20 erc20 = IERC20(subscriptionData.underlying());
        require(
            erc20.balanceOf(u) >= underlying,
            "ArgoPayments: User have insufficient balance"
        );
        require(
            erc20.allowance(u, address(this)) >= underlying,
            "ArgoPayments: Insufficient allowance"
        );
        erc20.transferFrom(u, subscriptionData.escrow(), underlying);
    }

    /**
     * @dev calculate price in ARGO
     * @param a total amount in USD
     * @return price in ArGo
     */
    function _calculatePriceInArgo(uint256 a) internal view returns (uint256) {
        uint256 underlyingPrice = subscriptionData.getUnderlyingPrice();
        return (a * DECIMAL) / underlyingPrice;
    }

    /**
     * @dev calculate discount that user gets for staking
     * @param u address of user that needs to be charged
     * @param a amount the user will pay without discount
     * @return discount that user will get
     */
    function _calculateDiscount(address u, uint256 a)
        internal
        view
        returns (uint256)
    {
        if (!subscriptionData.discountsEnabled()) return 0;
        IStaking stakingManager = IStaking(subscriptionData.stakingManager());
        uint256 stake = stakingManager.balanceOf(
            u,
            address(subscriptionData.stakedToken())
        );
        uint256[] memory discountSlabs = subscriptionData
            .slabs();
        uint256[] memory discountPercents = subscriptionData
            .discountPercents();
        uint256 length = discountSlabs.length;
        uint256 percent = 0;
        for (uint256 i = 0; i < length; i++) {
            if (stake >= discountSlabs[i]) {
                percent = discountPercents[i];
            } else {
                break;
            }
        }
        return (a * percent * PRECISION) / PERCENT;
    }
    /**
     * @notice update subscriptionDataContract
     * @param d data contract address
     */
    function updateDataContract(address d) external onlyManager {
        require(
            d != address(0),
            "ArgoSubscriptionPayments: data contract address can not be zero address"
        );
        subscriptionData = ISubscriptionData(d);
    }
    /**
     * @notice withdraw any erc20 send accidentally to the contract
     * @param t address of erc20 token
     * @param a amount of tokens to withdraw
     */
    function withdrawERC20(address t, uint256 a) external onlyManager {
        IERC20 erc20 = IERC20(t);
        require(
            erc20.balanceOf(address(this)) >= a,
            "ArgoSubscriptionData: Insufficient tokens in contract"
        );
        erc20.transfer(msg.sender, a);
    }
}
