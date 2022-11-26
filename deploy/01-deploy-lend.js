const { network } = require("hardhat")
const { verify } = require("../utils/verify")

module.exports = async function({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    const lend = await deploy("Lend", {
        from: deployer,
        args: [],
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if(network.name != "localhost" && network.name != "hardhat" && process.env.ETHERSCAN_API_KEY){
        await verify(lend.address, lend.args)
    }

    log("----------------------------------------")
}

module.exports.tags = ["all", "lend"]