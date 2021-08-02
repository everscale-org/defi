#!/usr/bin/env python3

# ==============================================================================
#
import freeton_utils
from   freeton_utils import *

class LiquidFTRoot(object):
    def __init__(self, tonClient: TonClient, name: str, symbol: str, decimals: int, signer: Signer=None):
        self.SIGNER      = generateSigner() if signer is None else signer
        self.TONCLIENT   = tonClient
        self.ABI         = "../bin/LiquidFTRoot.abi.json"
        self.TVC         = "../bin/LiquidFTRoot.tvc"
        self.TVC_WALLET  = "../bin/LiquidFTWallet.tvc"
        self.CODE        = getCodeFromTvc(self.TVC_WALLET)
        self.CONSTRUCTOR = {}
        self.INITDATA    = {"_walletCode":self.CODE, "_name":stringToHex(name), "_symbol":stringToHex(symbol), "_decimals":decimals}
        self.PUBKEY      = self.SIGNER.keys.public
        self.ADDRESS     = getAddress(abiPath=self.ABI, tvcPath=self.TVC, signer=self.SIGNER, initialPubkey=self.PUBKEY, initialData=self.INITDATA)

    #========================================
    #
    def deploy(self, ownerAddress: str):
        self.CONSTRUCTOR = {"ownerAddress":ownerAddress}
        result = deployContract(tonClient=self.TONCLIENT, abiPath=self.ABI, tvcPath=self.TVC, constructorInput=self.CONSTRUCTOR, initialData=self.INITDATA, signer=self.SIGNER, initialPubkey=self.PUBKEY)
        return result
    
    def _call(self, functionName, functionParams, signer):
        result = callFunction(tonClient=self.TONCLIENT, abiPath=self.ABI, contractAddress=self.ADDRESS, functionName=functionName, functionParams=functionParams, signer=signer)
        return result

    def _callFromMultisig(self, msig: SetcodeMultisig, functionName, functionParams, value, flags):
        messageBoc = prepareMessageBoc(abiPath=self.ABI, functionName=functionName, functionParams=functionParams)
        result     = msig.callTransfer(addressDest=self.ADDRESS, value=value, payload=messageBoc, flags=flags)
        return result

    def _run(self, functionName, functionParams):
        result = runFunction(tonClient=self.TONCLIENT, abiPath=self.ABI, contractAddress=self.ADDRESS, functionName=functionName, functionParams=functionParams)
        return result

    #========================================
    #
    
# ==============================================================================
# 
