const { ethers, network } = require("hardhat")
const fs = require("fs")

const FRONT_END_ADDRESSES_FILE = "../lend-frontend/constants/contractAddresses.json"
const FRONT_END_ABI_FILE = "../lend-frontend/constants/abi.json"

module.exports = async function () {
    if(process.env.UPDATE_FRONT_END){
        updateContractAddresses()
        updateAbi()
    }
}

async function updateAbi() {
    const lend = await ethers.getContract("Lend")
    fs.writeFileSync(FRONT_END_ABI_FILE, lend.interface.format(ethers.utils.FormatTypes.json))
}

async function updateContractAddresses() {
    const lend = await ethers.getContract("Lend")
    const chainId = network.config.chainId.toString()
    const currentAddresses = JSON.parse(fs.readFileSync(FRONT_END_ADDRESSES_FILE, "utf-8"))
    if(chainId in currentAddresses){
        if(!currentAddresses[chainId].includes(lend.address)){
            currentAddresses[chainId].push(lend.address)
        }
    } else {
        currentAddresses[chainId] = [lend.address]
    }
    fs.writeFileSync(FRONT_END_ADDRESSES_FILE, JSON.stringify(currentAddresses))
}

module.exports.tags = ["all", "frontend"]