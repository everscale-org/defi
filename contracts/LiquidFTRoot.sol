pragma ton-solidity >= 0.47.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
import "../interfaces/ILiquidFTRoot.sol";
import "../interfaces/IOwnable.sol";
import "../contracts/LiquidFTWallet.sol";
import "../contracts/DepoolKeeper.sol";

//================================================================================
//
struct KeeperInfo
{
    address depoolAddress;
    uint128 depoolFee;
    uint128 minimumDeposit;
    uint128 currentBalance;
    bool    frozen;
}

//================================================================================
//
contract LiquidFTRoot is IOwnable, ILiquidFTRoot
{
    //========================================
    // Error codes
    uint constant ERROR_WALLET_ADDRESS_INVALID = 301;
    uint constant ERROR_MINT_UNAVAILABLE       = 401;
    uint constant ERROR_WRONG_DECIMALS         = 400;
    uint constant ERROR_RECEIVE_UNAVAILABLE    = 402;
    uint constant ERROR_DEPOOL_IS_NOT_ADDED    = 403;
    uint constant ERROR_DEPOOL_FROZEN          = 404;
    uint constant ERROR_NOT_ENOUGH_MONEY       = 405;
    uint constant ERROR_INVALID_KEEPER         = 406;

    //========================================
    // Variables
    TvmCell static _walletCode;  //
    bytes   static _name;        //
    bytes   static _symbol;      //
    uint8   static _decimals;    //
    uint128        _totalSupply; //
    bytes[]        _icon;        // utf8-string with encoded PNG image, in chunks (concatenate all chunks to get the media). The string format is "data:image/png;base64,<image>", where image - image bytes encoded in base64.
                                 // _icon = "data:image/png;base64,iVBORw0KG...5CYII=";
    
    // Depool-specific variables
    uint128 _returnableFee;   // this portion of the fee is returned to the sender as change (used to pay for gas)
    uint128 _totalInvestment; // across all keepers
    TvmCell _keeperCode;      //
    mapping(address => KeeperInfo) _keepersList;

    //========================================
    // Modifiers

    //========================================
    // Getters
    function  getWalletCode()                        external view             override         returns (TvmCell)         {                                                        return                      (_walletCode);       }
    function callWalletCode()                        external view responsible override reserve returns (TvmCell)         {                                                        return {value: 0, flag: 128}(_walletCode);       }
    function  getWalletAddress(address ownerAddress) external view             override         returns (address)         {    (address addr, ) = _getWalletInit(ownerAddress);    return                      (addr);              }
    function callWalletAddress(address ownerAddress) external view responsible override reserve returns (address)         {    (address addr, ) = _getWalletInit(ownerAddress);    return {value: 0, flag: 128}(addr);              }

    function  getRootInfo(bool includeIcon) external view override returns (bytes name, bytes symbol, uint8 decimals, uint128 totalSupply, bytes[] icon)
    {
        return (_name, _symbol, _decimals, _totalSupply, includeIcon ? _icon : icon);  
    }
    function callRootInfo(bool includeIcon) external view responsible override reserve returns (bytes name, bytes symbol, uint8 decimals, uint128 totalSupply, bytes[] icon)
    {
        return {value: 0, flag: 128}(_name, _symbol, _decimals, _totalSupply, includeIcon ? _icon : icon);
    }

    //========================================
    //
    constructor(address ownerAddress) public
    {
        require(_decimals == 9, ERROR_WRONG_DECIMALS); // be the same as TON Crystal

        tvm.accept();
        _totalSupply   = 0;
        _ownerAddress  = ownerAddress;
        _returnableFee = 0.5 ton;
    }

    //========================================
    //
    function setIcon(uint256 partNum, uint256 partsTotal, bytes data) external onlyOwner reserve returnChange
    {
        if(_icon.length != partsTotal)
        {
            delete _icon;
            _icon = new bytes[](partsTotal);
        }
        _icon[partNum] = data;
    }
    
    //========================================
    //
    function _getWalletInit(address ownerAddress) private inline view returns (address, TvmCell)
    {
        TvmCell stateInit = tvm.buildStateInit({
            contr: LiquidFTWallet,
            varInit: {
                _rootAddress:  address(this),
                _ownerAddress: ownerAddress
            },
            code: _walletCode
        });

        return (address(tvm.hash(stateInit)), stateInit);
    }

    //========================================
    //
    function _createWallet(address ownerAddress, address notifyOnReceiveAddress, uint128 tokensAmount, uint128 value, uint16 flag) internal view returns (address)
    {
        if(tokensAmount > 0)
        {
            revert(ERROR_MINT_UNAVAILABLE);
        }
        
        (address walletAddress, TvmCell stateInit) = _getWalletInit(ownerAddress);
        // Event
        emit walletCreated(ownerAddress, walletAddress);
        new LiquidFTWallet{value: value, flag: flag, bounce: false, stateInit: stateInit, wid: address(this).wid}(addressZero, msg.sender, notifyOnReceiveAddress, tokensAmount);

        return walletAddress;
    }

    //========================================
    //
    function createWallet(address ownerAddress, address notifyOnReceiveAddress, uint128 tokensAmount) external override reserve returns (address)
    {
        address walletAddress = _createWallet(ownerAddress, notifyOnReceiveAddress, tokensAmount, 0, 128);
        return(walletAddress);
    }

    function callCreateWallet(address ownerAddress, address notifyOnReceiveAddress, uint128 tokensAmount) external responsible override reserve returns (address)
    {
        address walletAddress = _createWallet(ownerAddress, notifyOnReceiveAddress, tokensAmount, msg.value / 2, 0);
        return{value: 0, flag: 128}(walletAddress);
    }

    //========================================
    //
    function burn(uint128 amount, address senderOwnerAddress, address initiatorAddress) external override reserve
    {
        (address walletAddress, ) = _getWalletInit(senderOwnerAddress);
        require(walletAddress == msg.sender, ERROR_WALLET_ADDRESS_INVALID);
        
        // Initiate the return before we decrease the supply
        _withdrawPart(amount, initiatorAddress);

        _totalSupply -= amount;

        // Event
        emit tokensBurned(amount, senderOwnerAddress);

        // Return the change
        initiatorAddress.transfer(0, true, 128);
    }

    //========================================
    //
    function mint(uint128 amount, address targetOwnerAddress, address notifyAddress, TvmCell body) external override onlyOwner reserve
    {
        amount; targetOwnerAddress; notifyAddress; body; // shut the warnings
        revert(ERROR_MINT_UNAVAILABLE);
    }

    //========================================
    //
    onBounce(TvmSlice slice) external 
    {
		uint32 functionId = slice.decode(uint32);
		if (functionId == tvm.functionId(LiquidFTWallet.receiveTransfer)) 
        {
			uint128 amount = slice.decode(uint128);
            _totalSupply -= amount;

            // We know for sure that initiator in "mint" process is RTW owner;
            _ownerAddress.transfer(0, true, 128);
		}
	}

    //========================================
    //========================================
    //========================================
    //========================================
    //
    receive() external pure
    {
        revert(ERROR_RECEIVE_UNAVAILABLE);
    }

    //========================================
    //
    function getFee() external view returns (uint128) { return _returnableFee;  }

    function getTonsFromTokens(uint128 amountTokens) public view returns(uint128)
    {
        if(_totalSupply == 0)
        {
            return amountTokens;
        }
        return math.muldiv(_totalInvestment, amountTokens, _totalSupply);
    }

    function getTokensFromTons(uint128 amountTons) public view returns(uint128)
    {
        if(_totalSupply == 0)
        {
            return amountTons;
        }
        return math.muldiv(_totalSupply, amountTons, _totalInvestment);
    }

    //========================================
    //
    function setReturnableFee(uint128 fee) external onlyOwner reserve returnChange
    {
        _returnableFee = fee;
    }

    //========================================
    //
    function setKeeperCode(TvmCell code) external onlyOwner reserve returnChange
    {
        _keeperCode = code;
    }

    //========================================
    //
    function _getKeeperInit(address depoolAddress) private inline view returns (address, TvmCell)
    {
        TvmCell stateInit = tvm.buildStateInit({
            contr: DepoolKeeper,
            varInit: {
                _rootAddress:   address(this),
                _depoolAddress: depoolAddress
            },
            code: _keeperCode
        });

        return (address(tvm.hash(stateInit)), stateInit);
    }

    //========================================
    //
    function addKeeper(address depoolAddress, uint128 depoolFee, uint128 minimumDeposit) external onlyOwner reserve
    {
        bool creatingKeeper = !_keepersList.exists(depoolAddress);
        if(creatingKeeper)
        {
            (, TvmCell keeperInit) = _getKeeperInit(depoolAddress);
            new DepoolKeeper{value:0, flag: 128, stateInit: keeperInit, wid: address(this).wid}(depoolFee);
        }
        
        _keepersList[depoolAddress].depoolAddress  = depoolAddress;
        _keepersList[depoolAddress].depoolFee      = depoolFee;
        _keepersList[depoolAddress].minimumDeposit = minimumDeposit;

        if(!creatingKeeper)
        {
            msg.sender.transfer(0, true, 128);
        }
    }

    //========================================
    //
    function _mint(uint128 amount, uint128 attachValue, address targetOwnerAddress, address notifyAddress, TvmCell body) internal
    {
        address walletAddress = _createWallet(targetOwnerAddress, addressZero, 0, attachValue / 3, 0);
        // Event
        emit tokensMinted(amount, targetOwnerAddress, body);

        if(notifyAddress != addressZero)
        {
            iFTNotify(notifyAddress).receiveNotification{value: attachValue / 3, flag: 0}(amount, targetOwnerAddress, msg.sender, body);
        }

        // Mint adds balance to root total supply
        _totalSupply += amount;
        ILiquidFTWallet(walletAddress).receiveTransfer{value: attachValue / 3, flag: 0}(amount, addressZero, _ownerAddress, notifyAddress, body);
    }
    
    //========================================
    //
    function addOrdinaryStake(address depoolAddress, address notifyAddress, TvmCell body) external override
    {
        uint128 amountWithoutFees = msg.value - _returnableFee - _keepersList[depoolAddress].depoolFee;
        require(_keepersList.exists(depoolAddress),                              ERROR_DEPOOL_IS_NOT_ADDED);
        require(!_keepersList[depoolAddress].frozen,                             ERROR_DEPOOL_FROZEN      );
        require(amountWithoutFees >= _keepersList[depoolAddress].minimumDeposit, ERROR_NOT_ENOUGH_MONEY   );

        _keepersList[depoolAddress].currentBalance += amountWithoutFees;
        _totalInvestment                           += amountWithoutFees;

        _mint(getTokensFromTons(amountWithoutFees), _returnableFee / 2, msg.sender, notifyAddress, body);

        (address keeperAddress, ) = _getKeeperInit(depoolAddress);
        DepoolKeeper(keeperAddress).addOrdinaryStake{value:0, flag: 128}(amountWithoutFees, msg.sender);
    }

    //========================================
    //
    function _withdrawPart(uint128 amount, address initiatorAddress) internal
    {
        uint128 tons          = getTonsFromTokens(amount);
        address keeperAddress = addressZero;

        for((address depoolAddress, KeeperInfo keeper) : _keepersList)
        {
            // TODO: fix, make partial withdrawals from multiple keepers available
            if(keeper.currentBalance <= tons)
            {
                continue;
            }
            (keeperAddress ,) = _getKeeperInit(depoolAddress);

            _keepersList[depoolAddress].currentBalance -= tons;
            _totalInvestment                           -= tons;

            // Root ensures that we have enough to withdraw, thus no checks here
            DepoolKeeper(keeperAddress).withdrawPart{value: msg.value / 2, flag: 0}(tons, initiatorAddress);

        }
    }

    //========================================
    //
    function onRoundComplete(address depoolAddress, uint128 totalAmount) external override returnChange
    {
        require(_keepersList.exists(depoolAddress), ERROR_DEPOOL_IS_NOT_ADDED);
        (address keeperAddress, ) = _getKeeperInit(depoolAddress);
        require(msg.sender == keeperAddress, ERROR_INVALID_KEEPER);

        _totalInvestment -= _keepersList[depoolAddress].currentBalance;
        _totalInvestment += totalAmount;

        _keepersList[depoolAddress].currentBalance = totalAmount;
    }
    
}

//================================================================================
//