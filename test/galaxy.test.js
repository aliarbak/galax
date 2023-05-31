const assert = require("chai").assert;
const web3 = require("web3");
const truffleAssert = require('truffle-assertions');

const Galaxy = artifacts.require("Galaxy");
const RawResource = artifacts.require("RawResource");
const MaterialResource = artifacts.require("MaterialResource");
const Food = artifacts.require("Food");
const Planet = artifacts.require("Planet");
const Business = artifacts.require("Business");

contract('Galaxy', (accounts) => {
    let galaxy, rawResource, foodAndDrinksResource, fmcgResource, vehicleResource, food;
    before(async () => {
        galaxy = await Galaxy.deployed();
        rawResource = await RawResource.deployed();
        foodAndDrinksResource = await MaterialResource.at(await galaxy.resource.call(2));
        fmcgResource = await MaterialResource.at(await galaxy.resource.call(3));
        vehicleResource = await MaterialResource.at(await galaxy.resource.call(4));
        food = await Food.at(await galaxy.item.call(1));
    });

    describe('name', () => {
        it('should return name', async () => {
            // when
            const name = await galaxy.name.call();

            // then 
            assert.equal(name, 'Galax Network');
        });
    });

    describe('createPlanet', () => {
        context('when paid amount is less than initial balance and planet creation cost', () => {
            it('should revert', async () => {
                // given
                const planetOwner = accounts[0];
                const planetName = "Pluto";
                const baseUri = "https://baseuri.com";
                const value = 100;
                const salt = web3.utils.asciiToHex("5")

                // when & then
                await truffleAssert.reverts(
                    galaxy.createPlanet(planetName, baseUri, value, salt, { from: planetOwner, value: 1000 }),
                    'Insufficent value');
            });
        });

        context('when paid amount is more than initial balance and planet creation cost', () => {
            it('should create a planet', async () => {
                // given
                const planetOwner = accounts[0];
                const planetName = "Pluto";
                const baseUri = "https://baseuri.com";
                const value = 100;
                const salt = web3.utils.asciiToHex("5");

                // when
                const result = await galaxy.createPlanet(planetName, baseUri, value, salt, { from: planetOwner, value: 100200 })

                // then
                const planetAddress = result.receipt.rawLogs[0].address;
                const planet = await Planet.at(planetAddress);
                assert.equal(await planet.owner.call(), planetOwner);
                truffleAssert.eventEmitted(
                    result,
                    "PlanetCreated",
                    (args) => args.id.toString() === "1",
                    "PlanetCreated event should be triggered"
                );
            });
        });
    });

    describe('createBusiness', () => {
        context('when caller is not planet', () => {
            it('should revert', async () => {
                // given
                const caller = accounts[2];
                const owner = accounts[3];
                const businessType = 1;

                // when & then
                await truffleAssert.reverts(
                    galaxy.createBusiness('Best Pizza', businessType, owner, { from: caller }),
                    'Caller is not a planet');
            });
        });

        context('when caller is planet', () => {
            context('when paid amount is lower than business creation cost', () => {
                it('should revert', async () => {
                    // given
                    const planetAddress = await createPlanet();
                    const owner = accounts[3];
                    const businessType = 1;

                    // when & then
                    await truffleAssert.reverts(
                        galaxy.createBusiness('Best Pizza', businessType, owner, { from: planetAddress, value: 100 }),
                        'Insufficent payment');
                });
            });

            context('when paid amount is higher than business creation cost', () => {
                context('when business type is invalid', () => {
                    it('should revert', async () => {
                        // given
                        const planetAddress = await createPlanet();
                        const owner = accounts[3];
                        const businessType = 100;

                        // when & then
                        await truffleAssert.reverts(
                            galaxy.createBusiness('Best Pizza', businessType, owner, { from: planetAddress, value: 100000 }),
                            'Invalid business type');
                    });
                });
            });

            const createPlanet = async () => {
                const planetOwner = accounts[0];
                const planetName = "Pluto";
                const baseUri = "https://baseuri.com";
                const value = 100;
                const salt = web3.utils.asciiToHex("5");

                const result = await galaxy.createPlanet(planetName, baseUri, value, salt, { from: planetOwner, value: 100200 });
                return result.receipt.rawLogs[0].address;
            }
        });
    });
});