const { MichelsonMap } = require("@taquito/taquito");

const Roulette = artifacts.require("Roulette");

const store = {
  initialized: false,
  betAmount: 0,
  necessaryBalance: 0,
  nextRoundTimestamp: 0,
  creator: "tz1ZDcc6MGxidty2jivtWBjnuo1mcSXf4Mmr",
  maxTezInContract: 0,
  winnings: new MichelsonMap(),
  payouts: new MichelsonMap(),
  numberRange: new MichelsonMap(),
  bets: new MichelsonMap()
}

module.exports = async(deployer) => {
  deployer.deploy(Roulette, store);
  //const RouletteInstance = await Roulette.deployed();
  //await RouletteInstance.initialize([["unit"]]);
};
