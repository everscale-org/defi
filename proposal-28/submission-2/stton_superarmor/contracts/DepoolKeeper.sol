pragma ton-solidity >= 0.47.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
import "../interfaces/ILiquidFTRoot.sol";
import "../interfaces/IParticipant.sol";
import "../interfaces/IBase.sol";

//================================================================================
//
contract DepoolKeeper is IParticipant, IBase
{
    //========================================
    // Error codes
    uint constant ERROR_MESSAGE_SENDER_IS_NOT_ROOT   = 101;
    uint constant ERROR_MESSAGE_SENDER_IS_NOT_DEPOOL = 102;

    //========================================
    // Variables
    address static _depoolAddress;    //
    address static _rootAddress;      //
    uint128        _depoolFee;        //
    uint128        _totalInvested;    //
    uint128        _uninvestedChange; //

    mapping(address => uint128) _withdrawList;
    address[] _depoolChangeWaiters;

    //========================================
    // Modifiers
    modifier onlyRoot()    {    require(msg.isInternal && _rootAddress   != addressZero && _rootAddress   == msg.sender,  ERROR_MESSAGE_SENDER_IS_NOT_ROOT  );    _;    }
    modifier onlyDepool()  {    require(msg.isInternal && _depoolAddress != addressZero && _depoolAddress == msg.sender,  ERROR_MESSAGE_SENDER_IS_NOT_DEPOOL);    _;    }
    
    // We don't want to spend uninvested change, but we also don't want to keep the current transaction change;
    modifier reserveLocal(){    tvm.rawReserve(_uninvestedChange, 0);    _;    }

    //========================================
    // Getters
    //function  getWalletCode() external view             override         returns (TvmCell) {    return                      (_walletCode);       }
    //function callWalletCode() external view responsible override reserve returns (TvmCell) {    return {value: 0, flag: 128}(_walletCode);       }

    //========================================
    //
    constructor(uint128 depoolFee) public onlyRoot
    {
        _gasReserve = 1000000;
        _depoolFee  = depoolFee;
    }

    //========================================
    //
    function addOrdinaryStake(uint128 amount, address initiatorAddress) external onlyRoot
    {
        // Root ensures that we have enough to deposit, thus no checks here
        _totalInvested += amount;
        _depoolChangeWaiters.push(initiatorAddress);
        IDepool(_depoolAddress).addOrdinaryStake{value: amount + _depoolFee, flag: 1}(uint64(amount));
    }

    function withdrawPart(uint128 amount, address initiatorAddress) external onlyRoot reserve reserveLocal
    {
        // Root ensures that we have enough to withdraw, thus no checks here
        _withdrawList[initiatorAddress] += amount;

        IDepool(_depoolAddress).withdrawPart{value: msg.value / 2, flag: 0}(uint64(amount));

        initiatorAddress.transfer(0, false, 128);
    }

    // We can't add anything other than Ordinary Stake because TONs are like security deposit for minted tokens and all
    // other stake types take this security from us.

    //function addVestingStake (uint64 stake, address beneficiary, uint32 withdrawalPeriod, uint32 totalPeriod)
    //function addLockStake    (uint64 stake, address beneficiary, uint32 withdrawalPeriod, uint32 totalPeriod)
    //function addVestingOrLock(uint64 stake, address beneficiary, uint32 withdrawalPeriod, uint32 totalPeriod, bool isVesting )


    //========================================
    //
    function onRoundComplete(
        uint64 roundId,
        uint64 reward,
        uint64 ordinaryStake,
        uint64 vestingStake,
        uint64 lockStake,
        bool   reinvest,
        uint8  reason) external override onlyDepool
    {
        tvm.accept();

        roundId; vestingStake; lockStake; reinvest; reason; // shut the warning
        
        _totalInvested += reward;

        // Everything more than 1 means withdrawal;
        // Sometimes the withdrawal can be more than we requested, for example 
        // when stake was not enoug min_stake in depool, we need to keep that in mind;
        if(msg.value > 1)
        {
            _uninvestedChange += (msg.value - 1);
            
            for((address ownerAddress, uint128 desiredAmount) : _withdrawList)
            {
                if(_uninvestedChange == 0) {  break;  }

                if(_uninvestedChange >= desiredAmount)
                {
                    ownerAddress.transfer(desiredAmount, false, 0);
                    _uninvestedChange -= desiredAmount;
                    _totalInvested    -= desiredAmount;
                    delete _withdrawList[ownerAddress];
                }
                else
                {
                    ownerAddress.transfer(_uninvestedChange, false, 0);
                    _totalInvested   -= _uninvestedChange;
                    _uninvestedChange = 0;
                    break;
                }
            }
        }
        
        tvm.rawReserve(_uninvestedChange, 0);

        ILiquidFTRoot(_rootAddress).onRoundComplete{value: 0, flag: 128}(_depoolAddress, uint128(ordinaryStake));
    }

    //========================================
    //
    function receiveAnswer(uint32 errcode, uint64 comment) external override onlyDepool reserve reserveLocal
    {
        comment; // shut the warning

        if(errcode == 0)
        {
            if(_depoolChangeWaiters.length > 0)
            {
                _depoolChangeWaiters[0].transfer(0, false, 128);
                delete _depoolChangeWaiters[0];
            }
        }
        else
        {
            uint128 change = (msg.value - _depoolFee / 2);
            _uninvestedChange += change;
            tvm.rawReserve(change, 0);

            if(_depoolChangeWaiters.length > 0)
            {
                _depoolChangeWaiters[0].transfer(0, false, 128);
                delete _depoolChangeWaiters[0];
            }
        }
    }

    //========================================
    //
    function onTransfer(address source, uint128 amount) external override onlyDepool
    { source; amount; }

    //========================================
    //
    receive() external
    { }

    //========================================
    //
    
}

//================================================================================
//
