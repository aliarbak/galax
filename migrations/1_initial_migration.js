const Galaxy = artifacts.require("Galaxy");
const RawResource = artifacts.require("RawResource");
const MaterialResource = artifacts.require("MaterialResource");
const Food = artifacts.require("Food");

module.exports = async function (deployer) {
    await deployer.deploy(RawResource, 1, "Galax Raw Resource", "GXRR");
    const rawResource = await RawResource.deployed();
    
    await deployer.deploy(MaterialResource, 2, "Galax Foods and Drinks Resource", "GFDR", 100, 1, [{ id: 1, amount: 100 }], { hunger: "1000000000000000000", thirstiness: "1000000000000000000", energy: "1000000000000000000" }, { skillFactor: 10, skillType: 1 });
    const foodsAndDrinksResource = await MaterialResource.deployed();
    
    await deployer.deploy(MaterialResource, 3, "Galax FMCG Resource", "GFMR", 100, 3, [{ id: 1, amount: 100 }], { hunger: "1000000000000000000", thirstiness: "1000000000000000000", energy: "1000000000000000000" }, { skillFactor: 10, skillType: 2 });
    const fmcgResource = await MaterialResource.deployed();

    await deployer.deploy(MaterialResource, 4, "Galax Vehicle Material Resource", "GFMR", 100, 4, [{ id: 1, amount: 100 }], { hunger: "1000000000000000000", thirstiness: "1000000000000000000", energy: "1000000000000000000" }, { skillFactor: 10, skillType: 3 });
    const vehicleResource = await MaterialResource.deployed();

    await deployer.deploy(Food, 1, 10, "Galax Foods", "GXF", 2, 100);
    const foodItem = await Food.deployed();

    await deployer.deploy(Galaxy, 'Galax Network', { planetCreation: 100000 }, [rawResource.address, foodsAndDrinksResource.address, fmcgResource.address, vehicleResource.address], [foodItem.address], 1);
    await Galaxy.deployed();
}
