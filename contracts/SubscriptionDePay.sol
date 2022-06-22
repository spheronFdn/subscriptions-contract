//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISubscriptionData.sol";
import "./interfaces/IStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SubscriptionDePay is Ownable, ReentrancyGuard {
    address private treasury;
    address private company;

    struct UserData {
        uint256 deposit;
        uint256 balance;
        string token;
        uint[] charges;
        
    }
    mapping(address => mapping(address => UserData)) public userData;
    bool public pauseDeposit;
    ISubscriptionData public subscriptionData;

    //For improved precision
    uint256 constant PRECISION = 10**25;
    uint256 constant PERCENT = 100 * PRECISION;

    mapping(address => uint256) public totalDeposit;
    mapping(address => uint256) public totalCharges;
    mapping(address => uint256) public companyFund;

    event UserCharged(address indexed user, uint256 indexed fee);
    event UserDeposit(address indexed user, address indexed token, uint256 indexed deposit);
    event UserWithdraw(address indexed user, address indexed token, uint256 indexed balance);
    event CompanyWithdraw(address indexed token, uint256 indexed balance);

    constructor(address _treasury, address _company, address _data) {
        require(
            _treasury != address(0),
            "SpheronSubscriptionPayments: Invalid address for treasury"
        );
        require(
            _company != address(0),
            "SpheronSubscriptionPayments: Invalid address for company"
        );
        require(
            _data != address(0),
            "SpheronSubscriptionPayments: Invalid address of subscription data contract"
        );
        subscriptionData = ISubscriptionData(_data);
        treasury = _treasury;
        company = _company;
        
    }
    /**
     * @notice only manager modifier
     *
     */
    modifier onlyManager() {
        bool isManager = subscriptionData.managerByAddress(msg.sender);
        address owner = owner();
        require(
            isManager || msg.sender == owner,
            "Only manager and owner can call this function"
        );
        _;
    }
    /**
     * @notice unchecked iterator increment for gas optimization
        * @param x uint256
     */
    function unsafeInc(uint x) private pure returns (uint) {
        unchecked { return x + 1;}
    }
    /**
     * @notice set address of the treasury
     * @param _treasury treasury address
     */
    function setTreasury(address _treasury) external onlyManager {
        treasury = _treasury;
    }
    /**
     * @notice set address of the company
     * @param _company company address
     */
    function setCompany(address _company) external onlyManager{
        company = _company;
    }
    /**
     * @notice deposit one of the accepted erc20 to the treasury
     * @param _token address of erc20 token
     * @param _amount amount of tokens to deposit to treasury
     */

    function userDeposit(address _token, uint _amount) external {
        require(!pauseDeposit, "Deposit is paused");
        require(
            subscriptionData.isAcceptedToken(_token),
            "SpheronSubscriptionPayments: Token not accepted"
        );
        require(
            _amount > 0,
            "SpheronSubscriptionPayments: Deposit must be greater than zero"
        );
        IERC20 erc20 = IERC20(_token);
        require(
            erc20.allowance(msg.sender, address(this)) >= _amount,
            "SpheronPayments: Insufficient allowance"
        );
        erc20.transferFrom(msg.sender, treasury, _amount);
        totalDeposit[_token] += _amount;
        userData[msg.sender][_token].deposit += _amount;
        userData[msg.sender][_token].balance += _amount;
        emit UserDeposit(msg.sender, _token, _amount); 
    }
    /**
     * @notice user token withdrawal one of the accepted erc20 to the treasury
     * @param _token address of erc20 token
     * @param _amount amount of tokens to be withdrawn from treasury
     */
    function userWithdraw(address _token, uint _amount) public nonReentrant {
        require(
            subscriptionData.isAcceptedToken(_token),
            "SpheronSubscriptionPayments: Token not accepted"
        );
        require(
            _amount > 0,
            "SpheronSubscriptionPayments: Balance must be greater than zero"
        );
        require(
            _amount <= userData[msg.sender][_token].balance,
            "SpheronSubscriptionPayments: Amount must be less than or equal to user balance"
        );
        IERC20 erc20 = IERC20(_token);
        require(
            erc20.allowance(treasury, address(this)) >= _amount,
            "SpheronPayments: Insufficient allowance"
        );
        userData[msg.sender][_token].balance -= _amount;
        erc20.transferFrom(treasury, msg.sender, _amount);
        emit UserWithdraw(msg.sender, _token, _amount); 
    }

    /**
     * @notice company token withdrawal of one of the accepted erc20 from the treasury
     * @param _token address of erc20 token
     * @param _amount amount of tokens to be withdrawn from treasury
     */
    function companyWithdraw(address _token, uint _amount) public nonReentrant {
        require(
            msg.sender == company,
            "Only callable by company"
        );
        require(
            subscriptionData.isAcceptedToken(_token),
            "SpheronSubscriptionPayments: Token not accepted"
        );
        require(
            _amount > 0,
            "SpheronPayments: Amount must be greater than zero"
        );
        require(
            _amount <= companyFund[_token],
            "SpheronSubscriptionPayments: Balance must be less than or equal to user balance"
        );
        IERC20 erc20 = IERC20(_token);
        require(
            erc20.allowance(treasury, address(this)) >= _amount,
            "SpheronPayments: Insufficient allowance"
        );
        companyFund[_token] -= _amount;
        erc20.transferFrom(treasury, company, _amount);
        emit UserWithdraw(msg.sender, _token, _amount); 
    }

    /**
     * @notice charge user for subscription
     * @param u user address
     * @param p parameters list for subscription payment
     * @param v value list for subscription payment
     * @param t address of token contract
     */
    function chargeUser(
        address u,
        string[] memory p,
        uint256[] memory v,
        address t
    ) external onlyManager {
        require(
            p.length == v.length,
            "SpheronSubscriptionPayments: unequal length of array"
        );
        require(
            subscriptionData.isAcceptedToken(t),
            "SpheronSubscriptionPayments: Token not accepted"
        );

        uint256 fee = 0;

        for (uint256 i = 0; i < p.length; i = unsafeInc(i)) {
            fee += v[i] * subscriptionData.priceData(p[i]);
        }
        uint256 discount = fee - _calculateDiscount(u, fee);
        uint256 underlying = _calculatePriceInToken(discount, t);
        require(
            underlying <= userData[u][t].balance,
            "SpheronSubscriptionPayments: Balance must be less than or equal to amount charged"
        );
        userData[u][t].balance -= underlying;
        userData[u][t].charges.push(underlying);
        totalCharges[t] += underlying;
        companyFund[t] += underlying;
        emit UserCharged(u, underlying);
    }

    /**
     * @notice change status for user deposit. On or off
     */
    function changeDepositStatus() public onlyManager {
        pauseDeposit = !pauseDeposit;
    }
    /**
     * @notice update subscriptionDataContract
     * @param d data contract address
     */
     
    function updateDataContract(address d) external onlyManager {
        require(
            d != address(0),
            "SpheronSubscriptionPayments: data contract address can not be zero address"
        );
        subscriptionData = ISubscriptionData(d);
    }

    /**
     * @dev calculate discount that user gets for staking
     * @param u address of user that needs to be charged
     * @param a amount the user will pay without discount
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
        uint256[] memory discountSlabs = subscriptionData.slabs();
        uint256[] memory discountPercents = subscriptionData.discountPercents();
        uint256 length = discountSlabs.length;
        uint256 percent = 0;
        for (uint256 i = 0; i < length; i = unsafeInc(i)) {
            if (stake >= discountSlabs[i]) {
                percent = discountPercents[i];
            } else {
                break;
            }
        }
        return (a * percent * PRECISION) / PERCENT;
    }

    /**
     * @dev calculate price in Spheron
     * @param a total amount in USD
     * @return t token address
     */
    function _calculatePriceInToken(uint256 a, address t)
        internal
        returns (uint256)
    {
        (
            string memory symbol,
            uint128 decimals,
            address tokenAddress,
            bool accepted,
            bool isChainLinkFeed,
            address priceFeedAddress,
            uint128 priceFeedPrecision
        ) = subscriptionData.acceptedTokens(t);
        uint256 precision = 10**decimals;
        a = _toPrecision(a, subscriptionData.usdPricePrecision(), decimals);
        uint256 underlyingPrice = subscriptionData.getUnderlyingPrice(t);
        return (a * precision) / underlyingPrice;
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
     * @notice Return user data
     * @param _token address of deposit ERC20 token
     * @param _user address of the user
     */
    function getUserData(address _user, address _token) public view returns (UserData memory) {
        return userData[_user][_token];
    }
    /**
     * @notice Return total deposits of all users for a token
     */
    function getTotalDeposit(address t) public view returns (uint256) {
        return totalDeposit[t];
    }
    /**
     * @notice Return total charges of all users for a token
     */
    function getTotalCharges(address t) public view returns (uint256) {
        return totalCharges[t];
    }

}