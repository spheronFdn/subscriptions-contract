//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.16;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStaking.sol";
import "./utils/GovernanceOwnable.sol";
import "./utils/MultiOwnable.sol";
import "./interfaces/IDiaOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SubscriptionData is GovernanceOwnable {

    using SafeERC20 for IERC20;
    // name => price
    mapping(string => uint256) public priceData;
    // paramName => paramStatus
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
    uint256 public constant maxNumber = 10;

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
    event UpdateEscrow(address indexed _escrow);

    /**
     * @notice initialise the contract
     * @param _params array of name of subscription parameter
     * @param _prices array of prices of subscription parameters
     * @param _escrow escrow address for payments
     * @param slabAmounts_ array of amounts that seperates different slabs of discount
     * @param slabPercents_ array of percent of discount user will get
     * @param _stakedToken address of staked token
     */
    constructor(
        string[] memory _params,
        uint256[] memory _prices,
        address _escrow,
        uint256[] memory slabAmounts_,
        uint256[] memory slabPercents_,
        address _stakedToken
    ) {
        require(
            _params.length == _prices.length,
            "SubscriptionData: unequal length of array"
        );
        require(
            _escrow != address(0),
            "SubscriptionData: Escrow address can not be zero address"
        );
        require(
            _stakedToken != address(0),
            "SubscriptionData: staked token address can not be zero address"
        );
        require(
            slabAmounts_.length == slabPercents_.length,
            "SubscriptionData: discount slabs array and discount amount array have different size"
        );
        require(_params.length > 0, "SubscriptionData: No parameters provided");
        require(_prices.length > 0, "SubscriptionData: No prices provided");
        require(
            slabAmounts_.length > 0 && slabAmounts_.length <= maxNumber, 
            "SubscriptionData: discount slabs out of range");
        require(
            slabPercents_.length > 0 && slabPercents_.length <=maxNumber, 
            "SubscriptionData: discount percents out of range");
        for (uint256 i = 0; i < _params.length; i = unsafeInc(i)) {
            require(!availableParams[_params[i]], "SubscriptionData: Parameter already exists");
            require(_prices[i] > 0, "SubscriptionData: Price of parameter can not be zero");
            string memory name = _params[i];
            uint256 price = _prices[i];
            priceData[name] = price;
            availableParams[name] = true;
            params.push(name);
            emit SubscriptionParameter(price, name);
        }
        stakedToken = IERC20(_stakedToken);
        escrow = _escrow;
        require(isIncremental(slabAmounts_), "SubscriptionData: discount slabs array is not incremental");
        require(isIncremental(slabPercents_), "SubscriptionData: discount percent array is not incremental");
        for (uint256 i = 0; i < slabAmounts_.length; i = unsafeInc(i)) {
            require(slabAmounts_[i] > 0, "SubscriptionData: discount slab amount can not be zero");
            require(slabPercents_[i] > 0, "SubscriptionData: discount slab percent can not be zero");
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

    function isIncremental(uint256[] memory _nnn) public pure returns (bool) {
        bool incremental = true;
        for (uint256 i = 0; i < _nnn.length - 1; i++) {
            if (_nnn[i] > _nnn[i+1]) {
                incremental = false;
                break;
            }
        }
        return incremental;
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
        require(_params.length <= maxNumber, "Subscription Data: too much parameters");

        for (uint256 i = 0; i < _params.length; i = unsafeInc(i)) {
            string memory name = _params[i];
            priceData[name] = 0;
            if (availableParams[name]) {
                availableParams[name] = false;
                for (uint256 j = 0; j < params.length; j = unsafeInc(j)) {
                    if (
                        keccak256(abi.encodePacked(params[j])) ==
                        keccak256(abi.encodePacked(name))
                    ) {
                        params[j] = params[params.length - 1];
                        params.pop();
                        break;
                    }
                }
                emit DeletedParameter(name);
            }
            
        }
    }
    /**
     * @notice update escrow address
     * @param _escrow address for new escrow
     */
    function updateEscrow(address _escrow) external onlyManager {
        require(escrow != address(0), "Subscription Data: Escrow address can not be zero address");
        escrow = _escrow;
        emit UpdateEscrow(_escrow);
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
     * @notice delete previously set discount slabs and input new discount slabs
     * @param slabAmounts_ array of amounts that seperates different slabs of discount
     * @param slabPercents_ array of percent of discount user will get
     */
    function updateDiscountSlabs(
        uint256[] memory slabAmounts_,
        uint256[] memory slabPercents_
    ) public onlyGovernanceAddress {
        require(
            slabAmounts_.length == slabPercents_.length,
            "SubscriptionData: discount slabs array and discount amount array have different size"
        );
        require(
            slabPercents_.length <= maxNumber,
            "SubscriptionData: discount slabs array can not be more than 10"
        );
        delete discountSlabs;
        require(isIncremental(slabAmounts_), "SubscriptionData: discount slabs array is not incremental");
        require(isIncremental(slabPercents_), "SubscriptionData: discount percent array is not incremental");
        for (uint256 i = 0; i < slabAmounts_.length; i = unsafeInc(i)) {
            require(slabAmounts_[i] > 0, "SubscriptionData: discount slab amount can not be zero");
            require(slabPercents_[i] > 0, "SubscriptionData: discount slab percent can not be zero");
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
            "SubscriptionData: staking manager address can not be zero address"
        );
        discountsEnabled = true;
        stakingManager = IStaking(s);
    }

    /**
     * @notice add new token for payments
     * @param _symbols token symbols
     * @param _tokens token address
     * @param _decimals token decimals
     * @param isChainLinkFeed_ if price feed chain link feed
     * @param priceFeedAddress_ address of price feed
     * @param priceFeedPrecision_ precision of price feed

     */
    function addNewTokens(
        string[] memory _symbols,
        address[] memory _tokens,
        uint128[] memory _decimals,
        bool[] memory isChainLinkFeed_,
        address[] memory priceFeedAddress_,
        uint128[] memory priceFeedPrecision_
    ) external onlyGovernanceAddress {
        require(_symbols.length > 0, "SubscriptionData: No symbol provided");
        require(_tokens.length > 0, "SubscriptionData: No token provided");
        require(_decimals.length > 0, "SubscriptionData: No decimal provided");
        require(
            _symbols.length == _tokens.length,
            "SubscriptionData: token symbols and token address array length do not match"
        );

        require(
            _symbols.length == _decimals.length,
            "SubscriptionData: token symbols and token decimal array length do not match"
        );

        require(
            _symbols.length == priceFeedAddress_.length,
            "SubscriptionData: token symbols and price feed array length do not match"
        );

        require(
            _symbols.length == isChainLinkFeed_.length,
            "SubscriptionData: token symbols and is chainlink array length do not match"
        );
        require(
            _symbols.length == priceFeedAddress_.length,
            "SubscriptionData: token price feed  and token decimal array length do not match"
        );
        require(
            _symbols.length == priceFeedPrecision_.length,
            "SubscriptionData: token price feed precision and token decimal array length do not match"
        );

        for (uint256 i = 0; i < _symbols.length; i = unsafeInc(i)) {
            require(!acceptedTokens[_tokens[i]].accepted, "SubscriptionData: token already added");
            require(_tokens[i] != address(0), "SubscriptionData: token address can not be zero address");
            require(_decimals[i] > 0, "SubscriptionData: token decimal can not be zero");
            bytes memory tempEmptyStringTest = bytes(_symbols[i]);
            require(tempEmptyStringTest.length != 0, "SubscriptionData: token symbol can not be empty");
            Token memory token = Token(
                _symbols[i],
                _decimals[i],
                _tokens[i],
                true,
                isChainLinkFeed_[i],
                priceFeedAddress_[i],
                priceFeedPrecision_[i]
            );
            acceptedTokens[_tokens[i]] = token;
            tokens.push(_tokens[i]);
            isAcceptedToken[_tokens[i]] = true;
            emit TokenAdded(
                _tokens[i],
                _decimals[i],
                priceFeedAddress_[i],
                _symbols[i],
                isChainLinkFeed_[i],
                priceFeedPrecision_[i]
            );
        }
    }

    /**
     * @notice remove tokens for payment
     * @param t token address
     */
    function removeTokens(address[] memory t) external onlyGovernanceAddress {
        require(t.length > 0, "SubscriptionData: array length cannot be zero");
        require(t.length <= maxNumber, "SubscriptionData: too many tokens to remove");


        for (uint256 i = 0; i < t.length; i = unsafeInc(i)) {
            require(t[i] != address(0), "SubscriptionData: token address can not be zero address");
            if (acceptedTokens[t[i]].accepted) {
                require(tokens.length > 1, "Cannot remove all payment tokens");
                for (uint256 j = 0; j < tokens.length; j = unsafeInc(j)) {
                    if (tokens[j] == t[i]) {
                        tokens[j] = tokens[tokens.length - 1];
                        tokens.pop();
                        acceptedTokens[t[i]].accepted = false;
                        emit TokenRemoved(t[i]);
                    }
                }
                isAcceptedToken[t[i]] = false;

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
        require(p != 0, "SubscriptionData: USD to precision can not be zero");
        usdPricePrecision = p;
    }

    /**
     * @notice update staked token address
     * @param s new staked token address
     */
    function updateStakedToken(address s) external onlyGovernanceAddress {
        require(
            s != address(0),
            "SubscriptionData: staked token address can not be zero address"
        );
        stakedToken = IERC20(s);
    }

   /**
     * @notice get price of underlying token
     * @param t underlying token address
     * @return underlyingPrice of underlying token in usd
     * @return timestamp of underlying token in usd
     */
    function getUnderlyingPrice(address t) public view returns (uint256 underlyingPrice, uint256 timestamp) {
        Token memory acceptedToken = acceptedTokens[t];
        require(acceptedToken.accepted, "Token is not accepted");
        uint256 _price;
        uint256 _timestamp;
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
            _timestamp = uint256(timeStamp);
        } else {
            IDiaOracle priceFeed = IDiaOracle(acceptedToken.priceFeedAddress);
            (uint128 price, uint128 timeStamp) = priceFeed.getValue(
                acceptedTokens[t].symbol
            );
            _price = price;
            _timestamp = timeStamp;
        }
        uint256 price = _toPrecision(
            uint256(_price),
            acceptedToken.priceFeedPrecision,
            acceptedToken.decimals
        );
        return (price, _timestamp);
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
     * @notice withdraw any erc20 send accidentally to the contract
     * @param _token address of erc20 token
     * @param a amount of tokens to withdraw
     */
    function withdrawERC20(address _token, uint256 a) external onlyManager {
        require(_token != address(0), "SubscriptionData: token address can not be zero address");
        require(a > 0, "Amount must be greater than 0");
        IERC20 erc20 = IERC20(_token);
        require(
            erc20.balanceOf(address(this)) >= a,
            "SubscriptionData: Insufficient tokens in contract"
        );
        erc20.safeTransfer(msg.sender, a);
    }
    
}