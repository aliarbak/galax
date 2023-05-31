const assert = require("chai").assert;
const common = require("./common.js");
const truffleAssert = require('truffle-assertions');

const Galaxy = artifacts.require("Galaxy");
const RawResource = artifacts.require("RawResource");
const MaterialResource = artifacts.require("MaterialResource");
const Food = artifacts.require("Food");
const Planet = artifacts.require("Planet");
const Business = artifacts.require("Business");

contract('Planet', (accounts) => {
    let galaxy, charactersContractAddress, rawResource, foodAndDrinksResource, fmcgResource, vehicleResource, food;
    let planet, planetId;
    const planetOwner = accounts[0];
    before(async () => {
        galaxy = await Galaxy.deployed();
        charactersContractAddress = await galaxy.characters();
        rawResource = await RawResource.deployed();
        foodAndDrinksResource = await MaterialResource.at(await galaxy.resource.call(2));
        fmcgResource = await MaterialResource.at(await galaxy.resource.call(3));
        vehicleResource = await MaterialResource.at(await galaxy.resource.call(4));
        food = await Food.at(await galaxy.item.call(1));
        planet = await createPlanet();
        planetId = (await planet.id()).toString();
    });

    describe('createBusiness', () => {
        context('when caller is not planet owner', () => {
            it('should revert', async () => {
                // given
                const businessName = 'Best Pizza';
                const businessType = 1;
                const owner = accounts[1];

                // when & then
                await truffleAssert.reverts(
                    planet.createBusiness(businessName, businessType, owner, { from: accounts[2], value: 100 }),
                    'Ownable: caller is not the owner');
            });
        });

        context('when paid amount is higher than business creation cost', () => {
            it('should revert', async () => {
                // given
                const businessName = 'Best Pizza';
                const businessType = 1;
                const owner = accounts[1];

                // when & then
                await truffleAssert.reverts(
                    planet.createBusiness(businessName, businessType, owner, { from: planetOwner, value: 100 }),
                    'Insufficent payment');
            });
        })

        context('when paid amount is higher than business creation cost', () => {
            it('should create a business', async () => {
                // given
                const businessName = 'Best Pizza';
                const businessType = 1;
                const owner = accounts[1];

                // when
                const result = await planet.createBusiness(businessName, businessType, owner, { from: planetOwner, value: 100000 })

                // then
                assert.equal(await planet.businessCount(), 1);

                const business = await Business.at(result.receipt.rawLogs[0].address);
                assert.equal(await business.id(), 1);
                assert.equal(await business.name(), businessName);
                assert.equal(await business.businessType(), businessType);
                assert.equal((await business.planetId()).toString(), planetId);
            });
        })
    });

    describe('joinCharacter', () => {
        context('when caller is not planet owner', () => {
            it('should revert', async () => {
                // given
                const characterAddress = accounts[5];
                const nonce = 1000;
                const signatureType = 1;
                const signature = await common.characterSign(charactersContractAddress, characterAddress, planetId, nonce, signatureType);

                // when & then
                await truffleAssert.reverts(
                    planet.joinCharacter(characterAddress, signature, { from: accounts[2] }),
                    'Ownable: caller is not the owner');
            });
        });

        context('when signature is invalid', () => {
            it('should revert', async () => {
                // given
                const characterAddress = accounts[5];
                const nonce = 1000;
                const signatureType = 1;
                const signature = await common.characterSign(charactersContractAddress, characterAddress, planetId, nonce, signatureType);

                // when & then
                await truffleAssert.reverts(
                    planet.joinCharacter(characterAddress, signature, { from: planetOwner }),
                    'Invalid signature');
            });
        });

        context('when signature is valid', () => {
            it('should join character', async () => {
                // given
                const characterAddress = accounts[5];
                const nonce = 1;
                const signatureType = 1;
                const signature = await common.characterSign(charactersContractAddress, characterAddress, planetId, nonce, signatureType);

                // when
                await planet.joinCharacter(characterAddress, signature, { from: planetOwner });

                // then
                assert.equal((await planet.characterCount()).toString(), '1');
            });
        });
    });

    const createPlanet = async () => {
        const planetName = "Pluto";
        const baseUri = "https://baseuri.com";
        const value = 100;
        const salt = web3.utils.asciiToHex("5");

        const result = await galaxy.createPlanet(planetName, baseUri, value, salt, { from: planetOwner, value: 100200 });
        return Planet.at(result.receipt.rawLogs[0].address);
    }
});