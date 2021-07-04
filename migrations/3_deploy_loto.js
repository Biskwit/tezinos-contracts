const Loto = artifacts.require("Loto");

const store = {
  initialized: false,
  minAmount: 0,
  creator: "tz1ZDcc6MGxidty2jivtWBjnuo1mcSXf4Mmr",
  players: [],
  bannedUsers: [],
}

module.exports = async(deployer) => {
  deployer.deploy(Loto, store);
  //const LotoInstance = await Loto.deployed();
  //await LotoInstance.initialize([["unit"]]);
};
