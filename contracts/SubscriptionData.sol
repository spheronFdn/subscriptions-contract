//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStaking.sol";
import "./utils/GovernanceOwnable.sol";
import "./utils/MultiOwnable.sol";

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

    uint256 public constant MAX_NUMBER = 50;

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
            "unequal length of array"
        );
        require(
            _escrow != address(0),
            "Invalid escrow address"
        );
        require(
            _stakedToken != address(0),
            "Invalid stake address"
        );
        require(
            slabAmounts_.length == slabPercents_.length,
            "unequal length of array"
        );
        require(_params.length > 0, "Invalid params");
        require(_prices.length > 0, "Invalid prices");
        require(
            slabAmounts_.length <= MAX_NUMBER, 
            "discount slabs out of range");
        require(
            slabPercents_.length <= MAX_NUMBER, 
            "discount percents out of range");
        for (uint256 i = 0; i < _params.length; i = unsafeInc(i)) {
            require(!availableParams[_params[i]], "Parameter already exists");
            string memory name = _params[i];
            uint256 price = _prices[i];
            priceData[name] = price;
            availableParams[name] = true;
            params.push(name);
            emit SubscriptionParameter(price, name);
        }
        stakedToken = IERC20(_stakedToken);
        escrow = _escrow;
        for (uint256 i = 0; i < slabAmounts_.length; i = unsafeInc(i)) {
            require(slabAmounts_[i] > 0, "discount slab amount can not be zero");
            require(slabPercents_[i] > 0, "discount slab percent can not be zero");
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
        require(_params.length > 0, "No parameters provided");
        require(_prices.length > 0, "No prices provided");
        require(
            _params.length == _prices.length,
            "Subscription Data: unequal length of array"
        );
        for (uint256 i = 0; i < _params.length; i = unsafeInc(i)) {
            string memory name = _params[i];
            require(_prices[i] > 0, "Price of parameter can not be zero");
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
        require(_params.length != 0, "empty array");
        require(_params.length <= MAX_NUMBER, "too much parameters");

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
        uint256[] memory _percentage  = new uint256[](discountSlabs.length);
        for(uint256 i = 0 ; i< discountSlabs.length; i = unsafeInc(i)){
            _percentage[i] = discountSlabs[i].percent;
        }
        return _percentage;
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
            "discount slabs array and discount amount array have different size"
        );
        require(
            slabPercents_.length <= MAX_NUMBER,
            "discount slabs array can not be more than 10"
        );
        delete discountSlabs;
        require(isIncremental(slabAmounts_), "discount slabs array is not incremental");
        require(isIncremental(slabPercents_), "discount percent array is not incremental");
        for (uint256 i = 0; i < slabAmounts_.length; i = unsafeInc(i)) {
            require(slabAmounts_[i] > 0, "discount slab amount can not be zero");
            require(slabPercents_[i] > 0, "discount slab percent can not be zero");
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
            "staking manager address can not be zero address"
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
        require(_symbols.length > 0, "No symbol provided");
        require(_tokens.length > 0, "No token provided");
        require(_decimals.length > 0, "No decimal provided");
        require(
            _symbols.length == _tokens.length,
            "Invalid array"
        );

        require(
            _symbols.length == _decimals.length,
            "Invalid array"
        );

        require(
            _symbols.length == priceFeedAddress_.length,
            "Invalid array"
        );

        require(
            _symbols.length == isChainLinkFeed_.length,
            "Invalid array"
        );
        require(
            _symbols.length == priceFeedAddress_.length,
            "Invalid array"
        );
        require(
            _symbols.length == priceFeedPrecision_.length,
            "Invalid array"
        );

        for (uint256 i = 0; i < _symbols.length; i = unsafeInc(i)) {
            require(!acceptedTokens[_tokens[i]].accepted, "token already added");
            require(_tokens[i] != address(0), "token address can not be zero address");
            require(_decimals[i] > 0, "token decimal can not be zero");
            bytes memory tempEmptyStringTest = bytes(_symbols[i]);
            require(tempEmptyStringTest.length != 0, "token symbol can not be empty");
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
        require(t.length > 0, "array length cannot be zero");
        require(t.length <= MAX_NUMBER, "too many tokens to remove");
        for (uint256 i = 0; i < t.length; i = unsafeInc(i)) {
            require(t[i] != address(0), "token address can not be zero address");
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
        require(p != 0, "USD to precision can not be zero");
        usdPricePrecision = p;
    }

    /**
     * @notice update staked token address
     * @param s new staked token address
     */
    function updateStakedToken(address s) external onlyGovernanceAddress {
        require(
            s != address(0),
            "staked token address can not be zero address"
        );
        stakedToken = IERC20(s);
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
    
}