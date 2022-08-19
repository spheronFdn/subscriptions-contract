//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.16;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISubscriptionData.sol";
import "./interfaces/IStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "contracts/utils/ERC2771Context.sol";

contract SubscriptionDePay is Ownable, ReentrancyGuard, ERC2771Context {

    using SafeERC20 for IERC20;
    address private treasury;
    address private company;
    address private pendingCompany;

    struct UserData {
        uint256 deposit;
        uint256 balance;
    }
    struct UserSub {
        string[] params;
        uint256[] values;
        bool subscribed;
    }

    mapping(address => mapping(address => UserSub)) public userSub;    

    // (user => (token => UserData))
    mapping(address => mapping(address => UserData)) public userData;
    
    // to temporarily pause the deposit and withdrawal function
    bool public pauseDeposit;
    bool public pauseWithdrawal;

    ISubscriptionData public subscriptionData;

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
    event setTreasury(address indexed _treasury);
    event setCompany(address indexed _company);
    event DataContractUpdate(address indexed _dataContract);
    event DepositStatusChanged(bool _status);

    constructor(address _treasury, address _company, address _data, address _trustedForwarder) ERC2771Context(_trustedForwarder) {
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
    modifier onlyOwnerOrManager() {
        bool isManager = subscriptionData.managerByAddress(_msgSender());
        address owner = owner();
        require(
            isManager || _msgSender() == owner,
            "Only manager and owner can call this function"
        );
        _;
    }
    /**
     * @notice only company modifier
     *
     */
    modifier onlyCompany() {
        require(
            _msgSender() == company || _msgSender() == owner,
            "Only company and owner can call this function"
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
    function setTreasury(address _treasury) external onlyOwner {
        require(
            _treasury != address(0),
            "SpheronSubscriptionPayments: Invalid address for treasury"
        );
        treasury = _treasury;
        emit setTreasury(treasury);
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
    }
    /**
     * @notice set address of the company
     * @param _company company address
     */
    function approveSetCompany() external onlyOwnerOrManager {
        require(
            pendingCompany != address(0),
            "SpheronSubscriptionPayments: Invalid address for company"
        );
        company = pendingCompany;
        emit setCompany(company);
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
        uint256 preAmount = erc20.balanceOf(treasury);
        erc20.safeTransferFrom(_msgSender(), treasury, _amount);
        uint256 postAmount = erc20.balanceOf(treasury);
        uint256 amount = (postAmount - preAmount);
        totalDeposit[_token] += amount;
        userData[_msgSender()][_token].deposit += amount;
        userData[_msgSender()][_token].balance += amount;
        emit UserDeposit(_msgSender(), _token, amount); 
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
            "SpheronSubscriptionPayments: Balance must be less than or equal to user balance"
        );
        IERC20 erc20 = IERC20(_token);
        require(
            erc20.allowance(treasury, address(this)) >= _amount,
            "SpheronPayments: Insufficient allowance"
        );
        companyRevenue[_token] -= _amount;
        erc20.safeTransferFrom(treasury, company, _amount);
        emit UserWithdraw(_msgSender(), _token, _amount); 
    }

    /**
     * @notice charge user for one time charges
     * @param u user address
     * @param p parameters list for subscription payment
     * @param v value list for subscription payment
     * @param t address of token contract
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
            fee += v[i] * subscriptionData.priceData(_parameters[i]);
        }
        uint256 discountedFee = fee - _calculateDiscount(_user, fee);
        uint256 underlying = _calculatePriceInToken(discountedFee, _token);
        require(
            underlying <= userData[_user][_token].balance,
            "SpheronSubscriptionPayments: Balance must be less than or equal to amount charged"
        );
        userData[_user][_token].balance -= underlying;
        userData[_user][_token].charges.push(underlying);
        totalCharges[_token] += underlying;
        companyRevenue[_token] += underlying;
        emit UserCharged(_user, _token, underlying);
    }

    function userUpdateSub(
        address u,
        string[] memory p,
        uint256[] memory v,
        address t) {
        require(userSub);
        require(!userSub[u][t].subscribed, "Already subscribed");
        require(
            p.length == v.length,
            "SpheronSubscriptionPayments: unequal length of array"
        );
        require(
            subscriptionData.isAcceptedToken(t),
            "ArgoSubscriptionPayments: Token not accepted"
        );
        userSub[u][t].parameters = p;
        userSub[u][t].values = v;
        userSub[u][t].subscribed = true;

    }

    function userSubscribe(
        address u,
        string[] memory p,
        uint256[] memory v,
        address t) {
        require(userSub[u][t].subscribed, "Not subscribed");
        require(
            p.length == v.length,
            "SpheronSubscriptionPayments: unequal length of array"
        );
        require(
            subscriptionData.isAcceptedToken(t),
            "ArgoSubscriptionPayments: Token not accepted"
        );
        userSub[u][t].parameters = p;
        userSub[u][t].values = v;
        userSub[u][t].subscribed = true;
    }

    /**
     * @notice charge user for subscription
     * @param u user address
     * @param p parameters list for subscription payment
     * @param v value list for subscription payment
     * @param t address of token contract
     */
    function chargeUserSub(
        address u,
        address t
    ) external onlyOwnerOrManager {
        
        require(
            subscriptionData.isAcceptedToken(t),
            "SpheronSubscriptionPayments: Token not accepted"
        );
        string[] p = userSub[u][t].parameters;
        uint256[] v = userSub[u][t].values;
        uint256 fee = 0;


        for (uint256 i = 0; i < p.length; i = unsafeInc(i)) {
            fee += v[i] * subscriptionData.priceData(p[i]);
        }
        uint256 discountedFee = fee - _calculateDiscount(u, fee);
        uint256 underlying = _calculatePriceInToken(discountedFee, t);
        require(
            underlying <= userData[u][t].balance,
            "SpheronSubscriptionPayments: Balance must be less than or equal to amount charged"
        );
        userData[u][t].balance -= underlying;
        userData[u][t].charges.push(underlying);
        totalCharges[t] += underlying;
        companyRevenue[t] += underlying;
        emit UserCharged(u, t, underlying);
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
     * @dev calculate price in Spheron
     * @param a total amount in USD
     * @return t token address
     */
    function _calculatePriceInToken(uint256 a, address t)
        internal
        returns (uint256)
    {
        (, uint128 decimals, , , , , ) = subscriptionData.acceptedTokens(t);
        uint256 precision = 10**decimals;
        a = _toPrecision(a, subscriptionData.usdPricePrecision(), decimals);
        (uint256 underlyingPrice, uint timestamp) = subscriptionData.getUnderlyingPrice(t);
        require(timestamp == block.timestamp, "SpheronSubscriptionPayments: underlying price not updated");
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
    function _msgSender() internal view override(Context, ERC2771Context)
      returns (address sender) {
      sender = ERC2771Context._msgSender();
    }
    function _msgData() internal view override(Context, ERC2771Context)
      returns (bytes calldata) {
      return ERC2771Context._msgData();
    }
    function setTrustedForwarder(address _forwarder) public override onlyOwnerOrManager {
        ERC2771Context.setTrustedForwarder(_forwarder);
    }
    /**
     * @notice prevent the renouncement of the contract ownership by the owner
     */
    function renounceOwnership() public override {
        revert("SpheronSubscriptionPayments: cannot renounce ownership");
    }

}