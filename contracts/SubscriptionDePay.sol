//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;
import "./interfaces/ISubscriptionData.sol";
import "./interfaces/IStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./utils/ERC2771Context.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IDiaOracle.sol";

contract SubscriptionDePay is ReentrancyGuard, ERC2771Context {

    using SafeERC20 for IERC20;
    address public treasury;
    address public company;
    address public pendingCompany;

    struct UserData {
        uint256 deposit;
        uint256 balance;
    }
    mapping(address => mapping(address => UserData)) public userData;

    uint256 public timeStampGap;
    
    // to temporarily pause the deposit and withdrawal function

    bool public pauseDeposit;
    bool public pauseWithdrawal;

    //For improved precision
    uint256 constant PRECISION = 10**25;
    uint256 constant PERCENT = 100 * PRECISION;
    
    mapping(address => uint256) public totalDeposit; //(token => amount)
    mapping(address => uint256) public totalCharges; //(token => amount)
    mapping(address => uint256) public totalWithdraws; //(token => amount)
    mapping(address => uint256) public companyRevenue; //(token => amount)

    event UserCharged(address indexed user, address indexed token, uint256 fee);
    event UserDeposit(address indexed user, address indexed token, uint256 deposit);
    event UserWithdraw(address indexed user, address indexed token, uint256 amount);
    event CompanyWithdraw(address indexed token, uint256 amount);
    event TreasurySet(address indexed _treasury);
    event CompanySet(address indexed _company);
    event CompanyPendingSet(address indexed _company);
    event DataContractUpdated(address indexed _dataContract);
    event DepositStatusChanged(bool _status);
    event WithdrawalStatusChanged(bool _status);
    // event UserSubscribed(address indexed user, string[] params, uint256[] values);
    constructor(uint256 _timeStampGap, address _treasury, address _company, address _data, address _trustedForwarder) ERC2771Context(_trustedForwarder, _data) {
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
        timeStampGap = _timeStampGap;
        
    }
    // ROLES
    // Manager - limited to only contract data and does not have access to any funds. responsible for changing deposit and withdrawal status, adding tokens, updating params and other contract data.
    // Treasury - It would be a Mulitisg acocunt, mostly handled by the company or a governance or DAO
    // Company - It would be out account with mulitisig
    // Owner - owner of the contract, responsible for setting the treasury and company address and other core functions that involves users funds.
    /**
     * @notice only manager modifier
     *
     */
    modifier onlyOwnerOrManager() {
        require(
            subscriptionData.isManager(_msgSender()),
            "Only manager and owner can call this function"
        );
        _;
    }
    /**
        * @notice only company modifier
    */
    modifier onlyCompany() {
        address sender = _msgSender();
        require(sender == company || subscriptionData.isManager(sender), "Only company and managers can call this function");
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
    function setTreasury(address _treasury) external onlyOwnerOrManager {
        require(
            _treasury != address(0),
            "SpheronSubscriptionPayments: Invalid address for treasury"
        );
        treasury = _treasury;
        emit TreasurySet(treasury);
    }
    /**
     * @notice set address of the company
     * @param _company company address
     */
    function setCompany(address _company) external onlyCompany {
        require(
            _company != address(0),
            "SpheronSubscriptionPayments: Invalid address for company"
        );
        pendingCompany = _company;
        emit CompanyPendingSet(pendingCompany);
    }

    /**
     * @notice approve pending company address
     */

    function approveSetCompany(address _pendingCompany) external onlyOwnerOrManager {
        require(
            pendingCompany != address(0),
            "SpheronSubscriptionPayments: Invalid address for company"
        );
        require(
            _pendingCompany != address(0) && _pendingCompany == pendingCompany,
            "");
        company = pendingCompany;
        pendingCompany = address(0);
        emit CompanySet(company);
    }
    /**
     * @notice deposit one of the accepted erc20 to the treasury
     * @param _token address of erc20 token
     * @param _amount amount of tokens to deposit to treasury
     */

    function userDeposit(address _token, uint _amount) external nonReentrant {
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
            erc20.allowance(_msgSender(), address(this)) >= _amount,
            "SpheronPayments: Insufficient allowance"
        );
        erc20.safeTransferFrom(_msgSender(), treasury, _amount);
        totalDeposit[_token] += _amount;
        userData[_msgSender()][_token].deposit += _amount;
        userData[_msgSender()][_token].balance += _amount;
        emit UserDeposit(_msgSender(), _token, _amount); 
    }
    /**
     * @notice user token withdrawal one of the accepted erc20 to the treasury
     * @param _token address of erc20 token
     * @param _amount amount of tokens to be withdrawn from treasury
     */
    function userWithdraw(address _token, uint _amount) external nonReentrant {
        require(!pauseWithdrawal, "Withdrawal is paused");
        require(
            _amount > 0,
            "SpheronSubscriptionPayments: Amount must be greater than zero"
        );
        require(
            _amount <= userData[_msgSender()][_token].balance,
            "SpheronSubscriptionPayments: Amount must be less than or equal to user balance"
        );
        IERC20 erc20 = IERC20(_token);
        require(
            erc20.allowance(treasury, address(this)) >= _amount,
            "SpheronPayments: Insufficient allowance"
        );
        userData[_msgSender()][_token].balance -= _amount;
        totalWithdraws[_token] += _amount;
        erc20.safeTransferFrom(treasury, _msgSender(), _amount);
        emit UserWithdraw(_msgSender(), _token, _amount); 
    }
    /**
     * @notice company token withdrawal of one of the accepted erc20 from the treasury
     * @param _token address of erc20 token
     * @param _amount amount of tokens to be withdrawn from treasury
     */
    function companyWithdraw(address _token, uint _amount) public nonReentrant {
        require(
            _msgSender() == company,
            "Only callable by company"
        );
        require(
            _amount > 0,
            "SpheronPayments: Amount must be greater than zero"
        );
        require(
            _amount <= companyRevenue[_token],
            "SpheronSubscriptionPayments: Balance must be less than or equal to company balance"
        );
        IERC20 erc20 = IERC20(_token);
        require(
            erc20.allowance(treasury, address(this)) >= _amount,
            "SpheronPayments: Insufficient allowance"
        );
        companyRevenue[_token] -= _amount;
        erc20.safeTransferFrom(treasury, company, _amount);
        emit CompanyWithdraw(_token, _amount); 
    }

    /**
     * @notice charge user for one time charges
     * @param _user user address
     * @param _parameters list for subscription payment
     * @param _values value list for subscription payment
     * @param _token address of token contract
     */
    function chargeUser(
        address _user,
        string[] memory _parameters,
        uint256[] memory _values,
        address _token
    ) external onlyOwnerOrManager {
        require(_user != address(0), "SpheronSubscriptionPayments: Invalid user address");
        require(_token != address(0), "SpheronSubscriptionPayments: Invalid token address");
        require(
            _parameters.length > 0, "SpheronSubscriptionPayments: No params"
        );
        require(
            _values.length > 0, "SpheronSubscriptionPayments: No values"
        );
        require(
            _parameters.length == _values.length,
            "SpheronSubscriptionPayments: unequal length of array"
        );
        require(
            subscriptionData.isAcceptedToken(_token),
            "SpheronSubscriptionPayments: Token not accepted"
        );

        uint256 fee = 0;

        for (uint256 i = 0; i < _parameters.length; i = unsafeInc(i)) {
            fee += _values[i] * subscriptionData.priceData(_parameters[i]);
        }
        uint256 discountedFee = fee - _calculateDiscount(_user, fee);
        uint256 underlying = _calculatePriceInToken(discountedFee, _token);
        require(
            underlying <= userData[_user][_token].balance,
            "SpheronSubscriptionPayments: Balance must be less than or equal to amount charged"
        );
        userData[_user][_token].balance -= underlying;
        totalCharges[_token] += underlying;
        companyRevenue[_token] += underlying;
        emit UserCharged(_user, _token, underlying);
    }

    /**
     * @notice change status for user deposit. On or off
     */
    function changeDepositStatus() public onlyOwnerOrManager {
        pauseDeposit = !pauseDeposit;
        emit DepositStatusChanged(pauseDeposit);
    }

    /**
     * @notice change status for user deposit. On or off
     */
    function changeWithdrawalStatus() public onlyOwnerOrManager {
        pauseWithdrawal = !pauseWithdrawal;
        emit WithdrawalStatusChanged(pauseWithdrawal);
    }
    /**
     * @notice update subscriptionDataContract
     * @param d data contract address
     */
    function updateDataContract(address d) external onlyOwnerOrManager {
        require(
            d != address(0),
            "SpheronSubscriptionPayments: data contract address can not be zero address"
        );
        subscriptionData = ISubscriptionData(d);
        emit DataContractUpdated(d);
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
     * @notice get price of underlying token
     * @param t underlying token address
     * @return underlyingPrice of underlying token in usd
     * @return timestamp of underlying token in usd
     */
    function getUnderlyingPrice(address t) public view returns (uint256 underlyingPrice, uint256 timestamp) {
        (string memory symbol,
        uint128 decimals,
        ,
        bool accepted,
        bool isChainLinkFeed,
        address priceFeedAddress,
        uint128 priceFeedPrecision) = subscriptionData.acceptedTokens(t);
        require(accepted, "Token is not accepted");
        uint256 _price;
        uint256 _timestamp;
        if (isChainLinkFeed) {
            AggregatorV3Interface chainlinkFeed = AggregatorV3Interface(
                priceFeedAddress
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
            IDiaOracle priceFeed = IDiaOracle(priceFeedAddress);
            (uint128 price, uint128 timeStamp) = priceFeed.getValue(
                symbol
            );
            _price = price;
            _timestamp = timeStamp;
        }
        uint256 price = _toPrecision(
            uint256(_price),
            priceFeedPrecision,
            decimals
        );
        return (price, _timestamp);
    }
    /**
     * @dev calculate price in Spheron
     * @notice ensure that price is within 6 hour window
     * @param a total amount in USD
     * @return price
     */
    function _calculatePriceInToken(uint256 a, address t)
        internal
        returns (uint256)
    {
        (, uint128 decimals, , , , , ) = subscriptionData.acceptedTokens(t);
        uint256 precision = 10**decimals;
        a = _toPrecision(a, subscriptionData.usdPricePrecision(), decimals);
        (
            uint256 underlyingPrice,
            uint256 timestamp
        ) = getUnderlyingPrice(t);
        require((block.timestamp - timestamp) <= timeStampGap, "SpheronSubscriptionPayments: underlying price not updated");
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
    function updateTimeStampGap(uint256 _timeStampGap) external onlyOwnerOrManager {
        require(_timeStampGap > 0, "SpheronSubscriptionPayments: timestamp gap must be greater than 0");
        timeStampGap = _timeStampGap;
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
     * @notice Return total withdrawals of all users for a token
     */
    function getTotalWithdraws(address t) public view returns (uint256) {
        return totalWithdraws[t];
    }
    /**
     * @notice Return total charges of all users for a token
     */
    function getTotalCharges(address t) public view returns (uint256) {
        return totalCharges[t];
    }
    function _msgSender() internal view override(ERC2771Context)
      returns (address sender) {
      sender = ERC2771Context._msgSender();
    }
    function _msgData() internal view override(ERC2771Context)
      returns (bytes calldata) {
      return ERC2771Context._msgData();
    }

}