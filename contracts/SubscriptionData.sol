//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStaking.sol";
import "./utils/GovernanceOwnable.sol";
import "./utils/Pausable.sol";
import "./utils/MultiOwnable.sol";
import "./interfaces/IDiaOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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

    // would be true if discounts needs to be deducted
    bool public discountsEnabled;
    //Data for discounts
    struct Discount {
        uint256 amount;
        uint256 percent;
    }
    Discount[] public discountSlabs;

    //Accepted tokens
    struct Token {
        string symbol;
        uint128 decimals;
        address tokenAddress;
        bool accepted;
        bool isChainLinkFeed;
        address priceFeedAddress;
        uint128 priceFeedPrecision;
    }

    //mapping of accpeted tokens
    mapping(address => Token) public acceptedTokens;
    //mapping of bool for accepted tokens
    mapping(address => bool) public isAcceptedToken;

    // list of accepted tokens
    address[] public tokens;

    //values prcision, it will be in USD, like USDPRICE * 10 **18
    uint128 public usdPricePrecision;

    event SubscriptionParameter(uint256 indexed price, string param);
    event DeletedParameter(string param);
    event TokenAdded(
        address indexed tokenAddress,
        uint128 indexed decimals,
        address indexed priceFeedAddress,
        string symbol,
        bool isChainLinkFeed,
        uint128 priceFeedPrecision
    );
    event TokenRemoved(address indexed tokenAddress);

    /**
     * @notice initialise the contract
     * @param _params array of name of subscription parameter
     * @param _prices array of prices of subscription parameters
     * @param e escrow address for payments
     * @param slabAmounts_ array of amounts that seperates different slabs of discount
     * @param slabPercents_ array of percent of discount user will get
     * @param s address of staked token
     */
    constructor(
        string[] memory _params,
        uint256[] memory _prices,
        address e,
        uint256[] memory slabAmounts_,
        uint256[] memory slabPercents_,
        address s
    ) {
        require(
            _params.length == _prices.length,
            "ArgoSubscriptionData: unequal length of array"
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
            slabAmounts_.length == slabPercents_.length,
            "ArgoSubscriptionData: discount slabs array and discount amount array have different size"
        );
        for (uint256 i = 0; i < _params.length; i = unsafeInc(i)) {
            string memory name = _params[i];
            uint256 price = _prices[i];
            priceData[name] = price;
            availableParams[name] = true;
            params.push(name);
            emit SubscriptionParameter(price, name);
        }
        stakedToken = IERC20(s);
        escrow = e;
        for (uint256 i = 0; i < slabAmounts_.length; i = unsafeInc(i)) {
            Discount memory _discount = Discount(
                slabAmounts_[i],
                slabPercents_[i]
            );
            discountSlabs.push(_discount);
        }
        usdPricePrecision = 18;
    }
    // unchecked iterator increment for gas optimization
    function unsafeInc(uint x) private pure returns (uint) {
        unchecked { return x + 1;}
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
        for (uint256 i = 0; i < _params.length; i = unsafeInc(i)) {
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
        for (uint256 i = 0; i < _params.length; i = unsafeInc(i)) {
            string memory name = _params[i];
            priceData[name] = 0;
            if (!availableParams[name]) {
                availableParams[name] = false;
                for (uint256 j = 0; j < params.length; j = unsafeInc(j)) {
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
    function updateEscrow(address e) external onlyManager {
        escrow = e;
    }

    /**
     * @notice returns discount slabs array
     */
    function slabs() external view returns(uint256[] memory) {
        uint256[] memory _slabs  = new uint256[](discountSlabs.length);
        for(uint256 i = 0 ; i< discountSlabs.length; i = unsafeInc(i)){
            _slabs[i] = discountSlabs[i].amount;
        }
        return _slabs;
    }
    /**
     * @notice returns discount percents matched with slabs array
     */
    function discountPercents() external view returns(uint256[] memory) {
        uint256[] memory _percent  = new uint256[](discountSlabs.length);
        for(uint256 i = 0 ; i< discountSlabs.length; i = unsafeInc(i)){
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
        for (uint256 i = 0; i < slabAmounts_.length; i = unsafeInc(i)) {
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
    function enableDiscounts(address s) external onlyManager {
        require(
            s != address(0),
            "ArgoSubscriptionData: staking manager address can not be zero address"
        );
        discountsEnabled = true;
        stakingManager = IStaking(s);
    }

    /**
     * @notice add new token for payments
     * @param s token symbols
     * @param t token address
     * @param d token decimals
     * @param isChainLinkFeed_ if price feed chain link feed
     * @param priceFeedAddress_ address of price feed
     * @param priceFeedPrecision_ precision of price feed

     */
    function addNewTokens(
        string[] memory s,
        address[] memory t,
        uint128[] memory d,
        bool[] memory isChainLinkFeed_,
        address[] memory priceFeedAddress_,
        uint128[] memory priceFeedPrecision_
    ) external onlyGovernanceAddress {
        require(
            s.length == t.length,
            "ArgoSubscriptionData: token symbols and token address array length do not match"
        );

        require(
            s.length == d.length,
            "ArgoSubscriptionData: token symbols and token decimal array length do not match"
        );

        require(
            s.length == priceFeedAddress_.length,
            "ArgoSubscriptionData: token symbols and price feed array length do not match"
        );

        require(
            s.length == isChainLinkFeed_.length,
            "ArgoSubscriptionData: token symbols and is chainlink array length do not match"
        );
        require(
            s.length == priceFeedAddress_.length,
            "ArgoSubscriptionData: token price feed  and token decimal array length do not match"
        );
        require(
            s.length == priceFeedPrecision_.length,
            "ArgoSubscriptionData: token price feed precision and token decimal array length do not match"
        );

        for (uint256 i = 0; i < s.length; i = unsafeInc(i)) {
            if (!acceptedTokens[t[i]].accepted) {
                Token memory token = Token(
                    s[i],
                    d[i],
                    t[i],
                    true,
                    isChainLinkFeed_[i],
                    priceFeedAddress_[i],
                    priceFeedPrecision_[i]
                );
                acceptedTokens[t[i]] = token;
                tokens.push(t[i]);
                isAcceptedToken[t[i]] = true;
                emit TokenAdded(
                    t[i],
                    d[i],
                    priceFeedAddress_[i],
                    s[i],
                    isChainLinkFeed_[i],
                    priceFeedPrecision_[i]
                );
            }
        }
    }

    /**
     * @notice remove tokens for payment
     * @param t token address
     */
    function removeTokens(address[] memory t) external onlyGovernanceAddress {
        require(t.length > 0, "ArgoSubscriptionData: array length cannot be zero");

        for (uint256 i = 0; i < t.length; i = unsafeInc(i)) {
            if (acceptedTokens[t[i]].accepted) {
                require(tokens.length > 1, "Cannot remove all payment tokens");
                for (uint256 j = 0; j < tokens.length; j = unsafeInc(j)) {
                    if (tokens[j] == t[i]) {
                        tokens[j] = tokens[tokens.length - 1];
                        tokens.pop();
                        acceptedTokens[t[i]].accepted = false;
                    }
                    isAcceptedToken[t[i]] = false;
                    emit TokenRemoved(t[i]);
                }
            }
        }
    }

    /**
     * @notice disable discounts for users
     */
    function disableDiscounts() external onlyManager {
        discountsEnabled = false;
    }

    /**
     * @notice change precision of USD value
     * @param p new precision value
     */
    function changeUsdPrecision(uint128 p) external onlyManager {
        require(p != 0, "ArgoSubscriptionData: USD to precision can not be zero");
        usdPricePrecision = p;
    }

    /**
     * @notice update staked token address
     * @param s new staked token address
     */
    function updateStakedToken(address s) external onlyGovernanceAddress {
        require(
            s != address(0),
            "ArgoSubscriptionData: staked token address can not be zero address"
        );
        stakedToken = IERC20(s);
    }

   /**
     * @notice get price of underlying token
     * @param t underlying token address
     * @return price of underlying token in usd
     */
    function getUnderlyingPrice(address t) public view returns (uint256) {
        Token memory acceptedToken = acceptedTokens[t];

        int128 decimalFactor = int128(acceptedToken.decimals) -
            int128(acceptedToken.priceFeedPrecision);
        uint256 _price;
        if (acceptedToken.isChainLinkFeed) {
            AggregatorV3Interface chainlinkFeed = AggregatorV3Interface(
                acceptedToken.priceFeedAddress
            );
            (
                uint80 roundID,
                int256 price,
                uint256 startedAt,
                uint256 timeStamp,
                uint80 answeredInRound
            ) = chainlinkFeed.latestRoundData();
            _price = uint256(price);
        } else {
            IDiaOracle priceFeed = IDiaOracle(acceptedToken.priceFeedAddress);
            (uint128 price, uint128 timeStamp) = priceFeed.getValue(
                acceptedTokens[t].symbol
            );
            _price = price;
        }
        uint256 price = _toPrecision(
            uint256(_price),
            acceptedToken.priceFeedPrecision,
            acceptedToken.decimals
        );
        return price;
    }

    /**
     * @notice trim or add number for certain precision as required
     * @param a amount/number that needs to be modded
     * @param p older precision
     * @param n new desired precision
     * @return price of underlying token in usd
     */
    function _toPrecision(
        uint256 a,
        uint128 p,
        uint128 n
    ) internal pure returns (uint256) {
        int128 decimalFactor = int128(p) - int128(n);
        if (decimalFactor > 0) {
            a = a / (10**uint128(decimalFactor));
        } else if (decimalFactor < 0) {
            a = a * (10**uint128(-1 * decimalFactor));
        }
        return a;
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
        require(a > 0, "Amount must be greater than 0");
        IERC20 erc20 = IERC20(t);
        require(
            erc20.balanceOf(address(this)) >= a,
            "ArgoSubscriptionData: Insufficient tokens in contract"
        );
        erc20.transfer(msg.sender, a);
    }
    
}