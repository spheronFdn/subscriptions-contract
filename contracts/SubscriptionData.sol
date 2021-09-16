//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStaking.sol";
import "./utils/GovernanceOwnable.sol";
import "./utils/Pausable.sol";
import "./utils/MultiOwnable.sol";
import "./interfaces/IDiaOracle.sol";

contract SubscriptionData is GovernanceOwnable, Pausable {
    mapping(string => uint256) public priceData;
    mapping(string => bool) public availableParams;

    string[] public params;

    // address of escrow
    address public escrow;

    // interface for for staking manager
    IStaking public stakingManager;

    //erc20 used for staking
    IERC20 public stakedToken;

    //Oracle instance
    IDiaOracle public priceFeed;

    //Oracle feeder symbol
    string public feederSymbol;

    //erc20 used for payments
    IERC20 public underlying;

    // would be true if discounts needs to be deducted
    bool public discountsEnabled;
    //Data for discounts
    struct Discount {
        uint256 amount;
        uint256 percent;
    }
    Discount[] public discountSlabs;

    event SubscriptionParameter(uint256 indexed price, string param);
    event DeletedParameter(string param);

    /**
     * @notice initialise the contract
     * @param _params array of name of subscription parameter
     @ @param _prices array of prices of subscription parameters
     * @param u underlying token for payments
     * @param e escrow address for payments
     * @param slabAmounts_ array of amounts that seperates different slabs of discount
     * @param slabPercents_ array of percent of discount user will get
     * @param a price feed aggregator address
     * @param s address of staked token
     % @param f price feed symbol
     */
    constructor(
        string[] memory _params,
        uint256[] memory _prices,
        address u,
        address e,
        uint256[] memory slabAmounts_,
        uint256[] memory slabPercents_,
        address a,
        address s,
        string memory f
    ) {
        require(
            _params.length == _prices.length,
            "ArgoSubscriptionData: unequal length of array"
        );
        require(
            u != address(0),
            "ArgoSubscriptionData: Token address can not be zero address"
        );
        require(
            e != address(0),
            "ArgoSubscriptionData: Escrow address can not be zero address"
        );
        require(
            s != address(0),
            "ArgoSubscriptionData: staked token address can not be zero address"
        );
        require(
            a != address(0),
            "ArgoSubscriptionData: price feed address can not be zero address"
        );
        require(
            bytes(f).length != 0,
            "ArgoSubscriptionData: price feed symbol should have a value"
        );
        require(
            slabAmounts_.length == slabPercents_.length,
            "ArgoSubscriptionData: discount slabs array and discount amount array have different size"
        );
        for (uint256 i = 0; i < _params.length; i++) {
            string memory name = _params[i];
            uint256 price = _prices[i];
            priceData[name] = price;
            availableParams[name] = true;
            params.push(name);
            emit SubscriptionParameter(price, name);
        }
        priceFeed = IDiaOracle(a);
        stakedToken = IERC20(s);
        feederSymbol = f;
        underlying = IERC20(u);
        escrow = e;
        for (uint256 i = 0; i < slabAmounts_.length; i++) {
            Discount memory _discount = Discount(
                slabAmounts_[i],
                slabPercents_[i]
            );
            discountSlabs.push(_discount);
        }
    }

    /**
     * @notice update parameters
     * @param _params names of all the parameters to add or update
     * @param _prices list of prices of parameters index matched with _params
     */
    function updateParams(string[] memory _params, uint256[] memory _prices)
        external
        onlyManager
    {
        require(
            _params.length == _prices.length,
            "Subscription Data: unequal length of array"
        );
        for (uint256 i = 0; i < _params.length; i++) {
            string memory name = _params[i];
            uint256 price = _prices[i];
            priceData[name] = price;
            if (!availableParams[name]) {
                availableParams[name] = true;
                params.push(name);
            }
            emit SubscriptionParameter(price, name);
        }
    }

    /**
     * @notice delete parameters
     * @param _params names of all the parameters to be deleted
     */
    function deleteParams(string[] memory _params) external onlyManager {
        require(_params.length != 0, "Subscription Data: empty array");
        for (uint256 i = 0; i < _params.length; i++) {
            string memory name = _params[i];
            priceData[name] = 0;
            if (!availableParams[name]) {
                availableParams[name] = false;
                for (uint256 j = 0; j < params.length; j++) {
                    if (
                        keccak256(abi.encodePacked(params[j])) ==
                        keccak256(abi.encodePacked(name))
                    ) {
                        params[j] = params[params.length - 1];
                        delete params[params.length - 1];
                        break;
                    }
                }
            }
            emit DeletedParameter(name);
        }
    }

    /**
     * @notice update escrow address
     * @param e address for new escrow
     */
    function updateEscrow(address e) public onlyManager {
        escrow = e;
    }

    /**
     * @notice returns discount slabs array
     */
    function slabs() external view returns(uint256[] memory) {
        uint256[] memory _slabs  = new uint256[](discountSlabs.length);
        for(uint256 i = 0 ; i< discountSlabs.length; i++){
            _slabs[i] = discountSlabs[i].amount;
        }
        return _slabs;
    }
    /**
     * @notice returns discount percents matched with slabs array
     */
    function discountPercents() external view returns(uint256[] memory) {
        uint256[] memory _percent  = new uint256[](discountSlabs.length);
        for(uint256 i = 0 ; i< discountSlabs.length; i++){
            _percent[i] = discountSlabs[i].percent;
        }
        return _percent;
    }

    /**
     * @notice updates discount slabs
     * @param slabAmounts_ array of amounts that seperates different slabs of discount
     * @param slabPercents_ array of percent of discount user will get
     */
    function updateDiscountSlabs(
        uint256[] memory slabAmounts_,
        uint256[] memory slabPercents_
    ) public onlyGovernanceAddress {
        require(
            slabAmounts_.length == slabPercents_.length,
            "ArgoSubscriptionData: discount slabs array and discount amount array have different size"
        );
        delete discountSlabs;
        for (uint256 i = 0; i < slabAmounts_.length; i++) {
            Discount memory _discount = Discount(
                slabAmounts_[i],
                slabPercents_[i]
            );
            discountSlabs.push(_discount);
        }
    }

    /**
     * @notice enable discounts for users.
     * @param s address of staking manager
     */
    function enableDiscounts(address s) public onlyManager {
        require(
            s != address(0),
            "ArgoSubscriptionData: staking manager address can not be zero address"
        );
        discountsEnabled = true;
        stakingManager = IStaking(s);
    }

    /**
     * @notice disable discounts for users
     */
    function disableDiscounts() public onlyManager {
        discountsEnabled = false;
    }

    /**
     * @notice update staked token address
     * @param s new staked token address
     */
    function updateStakedToken(address s) public onlyGovernanceAddress {
        require(
            s != address(0),
            "ArgoSubscriptionData: staked token address can not be zero address"
        );
        stakedToken = IERC20(s);
    }

    /**
     * @notice update oracle feeder address
     * @param o new oracle feeder
     */
    function updateFeederAddress(address o) public onlyGovernanceAddress {
        require(
            o != address(0),
            "ArgoSubscriptionData: oracle feeder address can not be zero address"
        );
        priceFeed = IDiaOracle(o);
    }

    /**
     * @notice update oracle feeder symbol
     * @param s symbol of token
     */
    function updateFeederTokenSymbol(string memory s)
        public
        onlyGovernanceAddress
    {
        require(
            bytes(s).length != 0,
            "ArgoSubscriptionData: symbol length can not be zero"
        );
        feederSymbol = s;
    }

    /**
     * @notice update underlying token address
     * @param u underlying token address
     */
    function updateUnderlyingToken(address u) public onlyGovernanceAddress {
        require(
            u != address(0),
            "ArgoSubscriptionData: token address can not be zero address"
        );
        underlying = IERC20(u);
    }

    /**
     * @notice get price of underlying token
     * @return price of underlying token in usd
     */
    function getUnderlyingPrice() public view returns (uint256) {
        (uint128 price, uint128 timeStamp) = priceFeed.getValue(feederSymbol);
        return uint256(price) * (10**10);
    }

    /**
     * @notice pause charge user functions
     */
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /**
     * @notice unpause charge user functions
     */
    function unpause() external whenPaused onlyOwner {
        _unpause();
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