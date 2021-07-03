const Roulette = artifacts.require("Roulette");

contract('Roulette', () => {
    let rouletteInstance;
    let storage;

    // before(async () => {
    //     rouletteInstance = await Roulette.deployed();
    //     storage = await rouletteInstance.storage();
    //     assert.equal(storage, 0, "Storage was not set as 0.")
    // });

    it("Init", async () => {
        await rouletteInstance.init();
        storage = await rouletteInstance.storage([["unit"]]);
        assert.equal(storage.initialized, true, "Contract initialized.");
    });
});