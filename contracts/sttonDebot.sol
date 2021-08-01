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
import "../interfaces/IDebot.sol";
import "../interfaces/IUpgradable.sol";

//================================================================================
//
contract AuctionDebot is Debot, Upgradable
{
    address _sttonRtwAddress;
    address _msigAddress;

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

    }

}

//================================================================================
//