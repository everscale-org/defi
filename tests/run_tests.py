#!/usr/bin/env python3

# ==============================================================================
# 
import freeton_utils
from   freeton_utils import *
import binascii
import unittest
import time
import sys
from   pathlib import Path
from   pprint import pprint
from   contract_LiquidFTWallet import LiquidFTWallet
from   contract_LiquidFTRoot   import LiquidFTRoot
from   contract_FakeDepool     import FakeDepool

SERVER_ADDRESS = "https://net.ton.dev"

# ==============================================================================
#
def getClient():
    return TonClient(config=ClientConfig(network=NetworkConfig(server_address=SERVER_ADDRESS)))

# ==============================================================================
# 
# Parse arguments and then clear them because UnitTest will @#$~!
for _, arg in enumerate(sys.argv[1:]):
    if arg == "--disable-giver":
        
        freeton_utils.USE_GIVER = False
        sys.argv.remove(arg)

    if arg == "--throw":
        
        freeton_utils.THROW = True
        sys.argv.remove(arg)

    if arg.startswith("http"):
        
        SERVER_ADDRESS = arg
        sys.argv.remove(arg)

    if arg.startswith("--msig-giver"):
        
        freeton_utils.MSIG_GIVER = arg[13:]
        sys.argv.remove(arg)

# ==============================================================================
# EXIT CODE FOR SINGLE-MESSAGE OPERATIONS
# we know we have only 1 internal message, that's why this wrapper has no filters
def _getAbiArray():
    return ["../bin/SetcodeMultisigWallet.abi.json", "../bin/DepoolKeeper.abi.json", "../bin/FakeDepool.abi.json", "../bin/LiquidFTRoot.abi.json", "../bin/LiquidFTWallet.abi.json", "../bin/sttonDebot.abi.json"]

def _getExitCode(msgIdArray):
    abiArray     = _getAbiArray()
    msgArray     = unwrapMessages(getClient(), msgIdArray, abiArray)
    if msgArray != "":
        realExitCode = msgArray[0]["TX_DETAILS"]["compute"]["exit_code"]
    else:
        realExitCode = -1
    return realExitCode   

# ==============================================================================
# 
rootContract = LiquidFTRoot   (tonClient=getClient(), name="ST-TON", symbol="STTON", decimals=9)
depool       = FakeDepool     (tonClient=getClient())
msig1        = SetcodeMultisig(tonClient=getClient())
msig2        = SetcodeMultisig(tonClient=getClient())
msig3        = SetcodeMultisig(tonClient=getClient())

wallet2      = LiquidFTWallet(tonClient=getClient(), rootAddress=rootContract.ADDRESS, ownerAddress=msig2.ADDRESS)

giverGive(getClient(), rootContract.ADDRESS, TON * 1)
giverGive(getClient(), depool.ADDRESS,       TON * 1)
giverGive(getClient(), msig1.ADDRESS,        TON * 100)
giverGive(getClient(), msig2.ADDRESS,        TON * 100)
giverGive(getClient(), msig3.ADDRESS,        TON * 100)

result = msig1.deploy()
result = msig2.deploy()
result = msig3.deploy()

result = depool.deploy(ownerAddress=msig1.ADDRESS)
result = rootContract.deploy(ownerAddress=msig1.ADDRESS)
result = rootContract.setKeeperCode(msig=msig1, value=DIME, code=getCodeFromTvc("../bin/DepoolKeeper.tvc"))
result = rootContract.addKeeper(msig=msig1, value=TON, depoolAddress=depool.ADDRESS, depoolFee=DIME*5, minimumDeposit=TON*5)

result = depool.deploy(ownerAddress=msig1.ADDRESS)

# ==============================================================================
# 
class Test_01_TransferTonsToWrapper(unittest.TestCase):

    def test_0(self):
        print("\n\n----------------------------------------------------------------------")
        print("Running:", self.__class__.__name__)

    def test_1(self):
        result = rootContract.addOrdinaryStake(msig=msig2, value=TON*10, depoolAddress=depool.ADDRESS, notifyAddress=ZERO_ADDRESS, body="")
        #msgArray = unwrapMessages(getClient(), result[0].transaction["out_msgs"], _getAbiArray())
        #pprint(msgArray)

        rootInfo = rootContract.getRootInfo(includeIcon=False)
        self.assertEqual(rootInfo["totalSupply"], str(TON*9))
        walletInfo = wallet2.getBalance()
        self.assertEqual(walletInfo, str(TON*9))

# ==============================================================================
#       
class Test_02_SimulateDepoolRounds(unittest.TestCase):

    def test_0(self):
        print("\n\n----------------------------------------------------------------------")
        print("Running:", self.__class__.__name__)

    def test_1(self):
        result = depool.fakeMint(msig=msig1, value=TON*5)
        #msgArray = unwrapMessages(getClient(), result[0].transaction["out_msgs"], _getAbiArray())
        #pprint(msgArray)

# ==============================================================================
# 
class Test_03_WithdrawTons(unittest.TestCase):

    def test_0(self):
        print("\n\n----------------------------------------------------------------------")
        print("Running:", self.__class__.__name__)

    def test_1(self):
        result = wallet2.burn(msig=msig2, value=TON, amount=TON*4 + DIME*5)
        msgArray = unwrapMessages(getClient(), result[0].transaction["out_msgs"], _getAbiArray())
        pprint(msgArray)

# ==============================================================================
# 
"""
class Test_01_DeployAndTransfer(unittest.TestCase):

    hsig1 = HighloadSinglesig(tonClient=getClient())
    hsig2 = HighloadSinglesig(tonClient=getClient())
    hsig3 = HighloadSinglesig(tonClient=getClient())

    def test_0(self):
        print("\n\n----------------------------------------------------------------------")
        print("Running:", self.__class__.__name__)

    # 1. Giver
    def test_1(self):
        giverGive(getClient(), self.hsig1.ADDRESS, TON * 150)
        giverGive(getClient(), self.hsig2.ADDRESS, TON * 15)
        giverGive(getClient(), self.hsig3.ADDRESS, TON * 15)

    # 2. Deploy multisig
    def test_2(self):
        result = self.hsig1.deploy()
        self.assertEqual(result[1]["errorCode"], 0)
        result = self.hsig2.deploy()
        self.assertEqual(result[1]["errorCode"], 0)
        result = self.hsig3.deploy()
        self.assertEqual(result[1]["errorCode"], 0)

    # 3. Get info
    def test_3(self):

        result = self.hsig1.sendTransaction(addressDest=self.hsig2.ADDRESS, value=TON, bounce=False, flags=1, payload="")
        self.assertEqual(result[1]["errorCode"], 0)

        result = self.hsig1.sendTransaction(addressDest=self.hsig2.ADDRESS, value=TON, bounce=False, flags=1, payload="", signer=self.hsig2.SIGNER)
        self.assertEqual(result[1]["errorCode"], 100)
        
        print("")
        for i in range(0, 60):
            result = self.hsig1.sendTransaction(addressDest=self.hsig2.ADDRESS, value=TON, bounce=False, flags=1, payload="")
            print("count:", len(self.hsig1.getMessages()["messages"]), "fees:", result[0].fees.gas_fee)


    # 5. Cleanup
    def test_5(self):
        result = self.hsig1.destroy(addressDest = freeton_utils.giverGetAddress())
        self.assertEqual(result[1]["errorCode"], 0)
        result = self.hsig2.destroy(addressDest = freeton_utils.giverGetAddress())
        self.assertEqual(result[1]["errorCode"], 0)
        result = self.hsig3.destroy(addressDest = freeton_utils.giverGetAddress())
        self.assertEqual(result[1]["errorCode"], 0)
"""

# ==============================================================================
# 
unittest.main()
