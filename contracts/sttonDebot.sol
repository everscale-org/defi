pragma ton-solidity >=0.44.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
/// @title AuctionDebot
/// @author SuperArmor
/// @notice Debot for Auctions

//================================================================================
//
import "../interfaces/ILiquidFTRoot.sol";
import "../interfaces/ILiquidFTWallet.sol";
import "../interfaces/IDebot.sol";
import "../interfaces/IUpgradable.sol";

//================================================================================
//
contract AuctionDebot is Debot, Upgradable
{
    address _sttonRtwAddress;
    address _msigAddress;

    address _walletAddress;
    uint128 _walletBalance;
    int8    _walletAccType;

    address _depoolAddress;
    uint128 _depositAmount;
    uint128 _withdrawAmount;

    uint128 constant ATTACH_VALUE = 0.5 ton;

	//========================================
    //
    constructor(address ownerAddress) public 
    {
        tvm.accept();
        _ownerAddress = ownerAddress;
    }
    
    //========================================
    //
    function setRtwAddress(address rtwAddress) public 
    {
        require(msg.pubkey() == tvm.pubkey() || senderIsOwner(), ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER);
        tvm.accept();
        _sttonRtwAddress = rtwAddress;
    }

	//========================================
    //
	function getRequiredInterfaces() public pure returns (uint256[] interfaces) 
    {
        return [Terminal.ID, AddressInput.ID, NumberInput.ID, AmountInput.ID, Menu.ID];
	}

    //========================================
    //
    function getDebotInfo() public functionID(0xDEB) view returns(string name,     string version, string publisher, string key,  string author,
                                                                  address support, string hello,   string language,  string dabi, bytes icon)
    {
        name      = "st-TON DeBot (SuperArmor)";
        version   = "0.1.0";
        publisher = "@SuperArmor";
        key       = "st-TON DeBot from SuperArmor";
        author    = "@SuperArmor";
        support   = addressZero;
        hello     = "Welcome to SuperArmor's st-TON DeBot!";
        language  = "en";
        dabi      = _debotAbi.hasValue() ? _debotAbi.get() : "";
        icon      = _icon.hasValue()     ? _icon.get()     : "";
    }

    //========================================
    /// @notice Define DeBot version and title here.
    function getVersion() public override returns (string name, uint24 semver) 
    {
        (name, semver) = ("st-TON DeBot", _version(0, 2, 0));
    }

    function _version(uint24 major, uint24 minor, uint24 fix) private pure inline returns (uint24) 
    {
        return (major << 16) | (minor << 8) | (fix);
    }    

    //========================================
    // Implementation of Upgradable
    function onCodeUpgrade() internal override 
    {
        tvm.resetStorage();
    }

    //========================================
    //
    function onError(uint32 sdkError, uint32 exitCode) public override
    {
        Terminal.print(0, format("Failed! SDK Error: {}. Exit Code: {}", sdkError, exitCode));
        mainMenu(0); 
    }

    //========================================
    /// @notice Entry point function for DeBot.    
    function start() public override 
    {
        mainEnterDialog(0);
    }

    //========================================
    //
    function mainEnterDialog(uint32 index) public 
    {
        index = 0; // shut a warning

        if(_sttonRtwAddress == addressZero)
        {
            Terminal.print(0, "DeBot is being upgraded.\nPlease come back in a minute.\nSorry for inconvenience.");
            return;
        }

        AddressInput.get(tvm.functionId(onMsigEnter), "Let's start with entering your Multisig Wallet address: ");
    }

    //========================================
    //
    function onMsigEnter(address value) public
    {  
        _msigAddress = value;
        mainMenu(0);
    }

    function mainMenu(uint32 index) public 
    {
        index = 0; // shut a warning

        MenuItem[] mi;
        mi.push(MenuItem("Check my token balance", "", tvm.functionId(_checkBalance_1) ));
        mi.push(MenuItem("Deposit Stake",          "", tvm.functionId(_deposit_1)      ));
        mi.push(MenuItem("Withdraw Stake",         "", tvm.functionId(_withdraw_1)     ));
        mi.push(MenuItem("<- Restart",             "", tvm.functionId(mainEnterDialog) ));
        Menu.select("Enter your choice: ", "", mi);
    }

    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    //
    function _checkBalance_1(uint32 index) public
    {
        index; // shut a warning

        // Reset variables
        delete _walletAddress;
        delete _walletBalance;
        delete _walletAccType;

        ILiquidFTRoot(_sttonRtwAddress).getWalletAddress{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_checkBalance_2),
                        onErrorId:  0
                        }(_msigAddress);
    }

    function _checkBalance_2(address value) public 
    {
        _walletAddress = value;
        Sdk.getAccountType(tvm.functionId(_checkBalance_3), _walletAddress);
    }

    function _checkBalance_3(int8 acc_type) public
    {
        _walletAccType = acc_type;
        if(_walletAccType == -1 || _walletAccType == 0)
        {
            _checkBalance_4(0);
        }
        else
        {
            ILiquidFTWallet(_walletAddress).getBalance{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_checkBalance_4),
                        onErrorId:  0
                        }();
        }
    }

    function _checkBalance_4(uint128 amount) public
    {
        _walletBalance = amount;
        Terminal.print(0, format("Wallet Address: {:064x}\nBalance: {:t}", _walletAddress, _walletBalance));

        mainMenu(0);
    }

    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    //
    function _deposit_1(uint32 index) public
    {
        index; // shut a warning

        delete _depoolAddress;
        delete _depositAmount;

        AmountInput.get(tvm.functionId(_deposit_2), "Enter amount of TON Crystals to deposit: ", 9, 101000000000, 999999999999999999999999999999);
    }

    function _deposit_2(uint128 value) public
    {
        _depositAmount = value;
        AddressInput.get(tvm.functionId(_deposit_3), "Enter desired DePool address: ");
    }

    function _deposit_3(address value) public
    {
        _depoolAddress = value;

        TvmCell empty;
        TvmCell body = tvm.encodeBody(ILiquidFTRoot.addOrdinaryStake, _depoolAddress, addressZero, empty);
        _sendTransact(_msigAddress, _sttonRtwAddress, body, _depositAmount + 1 ton); // TODO: change 1 ton to some dynamic value
        _deposit_4(0);
    }
    
    function _deposit_4(uint32 index) public
    {
        index; // shut a warning
        
        Terminal.print(0, format("Deposited {:t} TON Crystals. Please check your Token Wallet now.", _depositAmount));
        mainMenu(0);
    }

    //========================================
    //========================================
    //========================================
    //========================================
    //========================================
    //
    function _withdraw_1(uint32 index) public
    {
        index; // shut a warning

        // Reset variables
        delete _walletAddress;
        delete _walletBalance;
        delete _walletAccType;

        ILiquidFTRoot(_sttonRtwAddress).getWalletAddress{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_withdraw_2),
                        onErrorId:  0
                        }(_msigAddress);
    }

    function _withdraw_2(address value) public 
    {
        _walletAddress = value;
        Sdk.getAccountType(tvm.functionId(_withdraw_3), _walletAddress);
    }

    function _withdraw_3(int8 acc_type) public
    {
        _walletAccType = acc_type;
        if(_walletAccType == -1 || _walletAccType == 0)
        {
            Terminal.print(0, "Token Wallet balance is 0, nothing to withdraw.");
            mainMenu(0);
        }
        else
        {
            ILiquidFTWallet(_walletAddress).getBalance{
                        abiVer: 2,
                        extMsg: true,
                        sign: false,
                        time: uint64(now),
                        expire: 0,
                        pubkey: _emptyPk,
                        callbackId: tvm.functionId(_withdraw_4),
                        onErrorId:  0
                        }();
        }
    }
    
    function _withdraw_4(uint128 amount) public
    {
        _walletBalance = amount;
        if(_walletBalance == 0)
        {
            Terminal.print(0, "Token Wallet balance is 0, nothing to withdraw.");
            mainMenu(0);
        }
        else
        {
            AmountInput.get(tvm.functionId(_withdraw_5), "Enter amount of Tokens return (in exchange to TON Crystals): ", 9, 1, _walletBalance);
        }
    }

    function _withdraw_5(uint128 value) public
    {
        _withdrawAmount = value;
        TvmCell body = tvm.encodeBody(ILiquidFTWallet.burn, _withdrawAmount);
        _sendTransact(_msigAddress, _walletAddress, body, _depositAmount + 1 ton); // TODO: change 1 ton to some dynamic value
    }
    
    function _withdraw_6(uint32 index) public
    {
        index; // shut a warning
        
        Terminal.print(0, format("{:t} Tokens withdrawn. Please check your Multisig now.", _withdrawAmount));
        mainMenu(0);
    }

}

//================================================================================
//