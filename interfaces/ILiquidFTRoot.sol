pragma ton-solidity >= 0.44.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
interface iFTNotify
{
    function receiveNotification(uint128 amount, address senderOwnerAddress, address initiatorAddress, TvmCell body) external;
}

//================================================================================
//
interface ILiquidFTRoot
{
    //========================================
    // Events
    event tokensMinted (uint128 amount,       address targetOwnerAddress, TvmCell body);
    event walletCreated(address ownerAddress, address walletAddress     );
    event tokensBurned (uint128 amount,       address senderOwnerAddress);

    //========================================
    // Getters
    function  getWalletCode()                        external view             returns (TvmCell walletCode);    // Wallet code;
    function callWalletCode()                        external view responsible returns (TvmCell walletCode);    // Wallet code, responsible;
    function  getWalletAddress(address ownerAddress) external view             returns (address walletAddress); // Arbitratry Wallet address;
    function callWalletAddress(address ownerAddress) external view responsible returns (address walletAddress); // Arbitratry Wallet address, responsible;
    function  getRootInfo(bool includeIcon)          external view             returns (bytes name, bytes symbol, uint8 decimals, uint128 totalSupply, bytes[] icon); // Token information + icon;
    function callRootInfo(bool includeIcon)          external view responsible returns (bytes name, bytes symbol, uint8 decimals, uint128 totalSupply, bytes[] icon); // Token information + icon, responsible;

    //========================================
    /// @notice Receives burn command from Wallet;
    ///
    /// @dev Burn is performed by Wallet, not by Root owner;
    ///
    /// @param amount             - Amount of tokens to burn;
    /// @param senderOwnerAddress - Sender Wallet owner address to calculate and verify Wallet address;
    /// @param initiatorAddress   - Transaction initiator (e.g. Multisig) to return the unspent change;
    //
    function burn(uint128 amount, address senderOwnerAddress, address initiatorAddress) external;

    //========================================
    /// @notice Mints tokens from Root to a target Wallet;
    ///
    /// @param amount             - Amount of tokens to mint;
    /// @param targetOwnerAddress - Receiver Wallet owner address to calculate Wallet address;
    /// @param notifyAddress      - "iFTNotify" contract address to receive a notification about minting (may be zero);
    /// @param body               - Custom body (business-logic specific, may be empty);
    //
    function mint(uint128 amount, address targetOwnerAddress, address notifyAddress, TvmCell body) external;

    //========================================
    /// @notice Creates a new Wallet with "tokensAmount" Tokens; "tokensAmount > 0" is available only for Root;
    ///         Returns wallet address;
    ///
    /// @param ownerAddress           - Receiver Wallet owner address to calculate Wallet address;
    /// @param notifyOnReceiveAddress - "iFTNotify" contract address to receive a notification when Wallet receives a transfer;
    /// @param tokensAmount           - When called by Root Owner, you can mint Tokens when creating a wallet;
    //
    function createWallet(address ownerAddress, address notifyOnReceiveAddress, uint128 tokensAmount) external returns (address);

    //========================================
    /// @notice Creates a new Wallet with "tokensAmount" "tokensAmount > 0" is available only for Root;
    ///         Returns wallet address;
    ///
    /// @param ownerAddress           - Receiver Wallet owner address to calculate Wallet address;
    /// @param tokensAmount           - When called by Root Owner, you can mint Tokens when creating a wallet;
    /// @param notifyOnReceiveAddress - "iFTNotify" contract address to receive a notification when Wallet receives a transfer;
    //
    function callCreateWallet(address ownerAddress, address notifyOnReceiveAddress, uint128 tokensAmount) external responsible returns (address);

    //========================================
    // st-ton functions
    function addOrdinaryStake(address depoolAddress, address notifyAddress, TvmCell body) external;
    function onRoundComplete (address depoolAddress, uint128 totalAmount)                 external;
}

//================================================================================
//
