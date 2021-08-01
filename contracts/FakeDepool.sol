pragma ton-solidity >= 0.47.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
import "../interfaces/IOwnable.sol";
import "../interfaces/IParticipant.sol";

//================================================================================
//
contract FakeDepool is IOwnable, IDepool
{
    //========================================
    // Error codes
    //uint constant ERROR_MESSAGE_SENDER_IS_NOT_ROOT   = 101;
    //uint constant ERROR_MESSAGE_SENDER_IS_NOT_DEPOOL = 102;

    //========================================
    // Variables
    //address static _depoolAddress; //
    //address static _rootAddress;   //
    //uint128        _totalInvested; //
    uint128 _depoolFee = 0.5 ton;
    uint128 _totalInvested;
    uint32  _totalInvestors;
    mapping(address => uint128) _investedAmount;

    //========================================
    // Modifiers
    //modifier onlyRoot()   {    require(msg.isInternal && _rootAddress   != addressZero && _rootAddress   == msg.sender,  ERROR_MESSAGE_SENDER_IS_NOT_ROOT  );    _;    }
    //modifier onlyDepool() {    require(msg.isInternal && _depoolAddress != addressZero && _depoolAddress == msg.sender,  ERROR_MESSAGE_SENDER_IS_NOT_DEPOOL);    _;    }

    //========================================
    //
    constructor(address ownerAddress) public
    {
        tvm.accept();
        _ownerAddress  = ownerAddress;
    }

    //========================================
    //
    function fakeMint() external onlyOwner
    {
        require(_totalInvestors > 0, 666);
        tvm.accept();

        // We don't care about investors' shares, we will give equal values to everyone for simplicity, 
        // because it doesn't matter in this case;
        uint128 distributeAmount  = msg.value - 1 ton;
        uint128 amountPerInvestor = distributeAmount / _totalInvestors;
        _totalInvested += distributeAmount;

        for((address investor, ) : _investedAmount)
        {
            _investedAmount[investor] += amountPerInvestor;
        }

        uint128 percentValue = 1 ton / _totalInvestors;
        for((address investor, ) : _investedAmount)
        {
            IParticipant(investor).onRoundComplete{value: 1, bounce: false, flag: 1}(
                13, // devil's round
                uint64(amountPerInvestor),
                uint64(_investedAmount[investor]),
                0,
                0,
                true,
                uint8(5)
            );
        }
    }

    //========================================
    //
    function addOrdinaryStake(uint64 stake) external override
    {
        if(!_investedAmount.exists(msg.sender))
        {
            _totalInvestors += 1;
        }
        _totalInvested += stake;
        _investedAmount[msg.sender] += stake;

        tvm.rawReserve(_totalInvested, 0);
        
        IParticipant(msg.sender).receiveAnswer{value: 0, bounce: false, flag: 128}(0, 0);
    }

    //========================================
    //
    function withdrawPart(uint64 withdrawValue) external override
    {
        _investedAmount[msg.sender] -= withdrawValue;

        IParticipant(msg.sender).onRoundComplete{value: 1+withdrawValue, bounce: false, flag: 1}(
                13, // devil's round
                0,
                uint64(_investedAmount[msg.sender]),
                0,
                0,
                true,
                uint8(5)
            );


        if(_investedAmount[msg.sender] == 0)
        {
            delete _investedAmount[msg.sender];
            _totalInvestors -= 1;
        }
    }

}
