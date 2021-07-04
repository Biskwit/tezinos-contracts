const { MichelsonMap } = require("@taquito/taquito");

const Blackjack = artifacts.require("Blackjack");

const store = {
    minBet: 1,
    maxBet: 5,
    blackjack: 21,
    games: new MichelsonMap(),
    bannedUsers: [],
}
// store.games.set("tz1ZDcc6MGxidty2jivtWBjnuo1mcSXf4Mmr", {
//   0: "tz1ZDcc6MGxidty2jivtWBjnuo1mcSXf4Mmr",
//   1: 0,
//   2: new MichelsonMap(),
//   3: new MichelsonMap(),
//   4: 0,
//   5: 0
// })

module.exports = async (deployer) => {
  deployer.deploy(Blackjack, store);
};
