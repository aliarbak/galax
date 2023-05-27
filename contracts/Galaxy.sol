// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Planet} from "./Planet.sol";
import {Galaxy} from "./Galaxy.sol";
import {Characters} from "./Characters.sol";
import {Resource} from "./Resource.sol";
import {Store} from "./Store.sol";
import {RawResource} from "./RawResource.sol";

contract Galaxy is Ownable, ReentrancyGuard {
    struct GalaxyCosts {
        uint256 planetCreation;
    }

    using Counters for Counters.Counter;
    Counters.Counter private _planetIds;
    Counters.Counter private _storeIds;
    Counters.Counter private _resourceIds;

    mapping(uint256 => Planet) public planet;
    mapping(address => uint256) public addressToPlanetId;
    mapping(uint256 => uint256) public planetOrbit;

    mapping(uint256 => Resource) public resource;
    mapping(address => uint256) public addressToResourceId;
    Resource[] public resources;

    mapping(uint256 => Store) public store;
    mapping(address => uint256) public addressToStoreId;

    RawResource public rawResource;
    Characters public characters;
    GalaxyCosts public costs;
    string public name;

    constructor(
        string memory _name,
        string memory rawResourceName,
        string memory rawResourceSymbol
    ) {
        name = _name;
        characters = new Characters();
        costs = GalaxyCosts(1000000); // TO DO
        _createRawResource(rawResourceName, rawResourceSymbol);
    }

    function createPlanet(
        string calldata planetName,
        uint256 _value,
        bytes32 _salt
    ) external payable nonReentrant returns (address planetAddress) {
        require(
            msg.value >= costs.planetCreation + _value,
            "Insufficent value"
        );

        _planetIds.increment();
        uint256 id = _planetIds.current();

        Planet _planet = (new Planet){value: _value, salt: _salt}(
            id,
            planetName,
            characters
        );
        planetAddress = address(_planet);

        planet[id] = _planet;
        addressToPlanetId[planetAddress] = id;

        _calculateOrbits();
        emit PlanetCreated(id, planetAddress);
    }

    function createStore(
        string calldata _name,
        Store.StoreType storeType,
        address ownerAddress
    ) external payable nonReentrant returns (Store _store) {
        uint256 planetId = addressToPlanetId[msg.sender];
        require(planetId > 0, "Caller is not a planet");

        uint256 storeCreationCost = calculateStoreCreationCost(planetId);
        require(msg.value >= storeCreationCost, "Insufficent payment");

        _storeIds.increment();
        uint256 storeId = _storeIds.current();

        _store = new Store(storeId, _name, planetId, storeType);
        _store.transferOwnership(ownerAddress);

        store[storeId] = _store;
        addressToStoreId[address(_store)] = storeId;
    }

    function calculateOrbitDiff(
        uint256 fromPlanetId,
        uint256 toPlanetId
    ) public view returns (uint256) {
        uint256 fromPlanetOrbit = planetOrbit[fromPlanetId];
        uint256 toPlanetOrbit = planetOrbit[toPlanetId];

        if (fromPlanetOrbit == 0 || toPlanetOrbit == 0) {
            return 0;
        }

        if (fromPlanetOrbit > toPlanetOrbit) {
            return fromPlanetOrbit - toPlanetOrbit;
        }

        return toPlanetOrbit - fromPlanetOrbit;
    }

    function calculateArrivalTimeToPlanet(
        uint256 fromPlanetId,
        uint256 toPlanetId
    ) public view returns (uint256) {
        uint256 movingTimeInSec = 1000;
        uint256 orbitDiff = calculateOrbitDiff(fromPlanetId, toPlanetId);
        if (orbitDiff > 0) {
            movingTimeInSec = orbitDiff;
        }

        return ((block.timestamp + movingTimeInSec) / 1000) * 1000;
    }

    function calculateStoreCreationCost(
        uint256 planetId
    ) public pure returns (uint256) {
        return 100000; // TO DO
    }

    function _createRawResource(
        string memory resourceName,
        string memory resourceSymbol
    ) private {
        _resourceIds.increment();
        uint256 resourceId = _resourceIds.current();
        rawResource = new RawResource(resourceId, resourceName, resourceSymbol);
        resource[resourceId] = rawResource;
        addressToResourceId[address(rawResource)] = resourceId;
        resources.push(rawResource);
    }

    // Min orbit  = 1  max orbit = 100.000
    function _calculateOrbits() private {
        // TO DO
        uint256 totalPlanetsBalance = 0;
        uint256 toPlanetId = _planetIds.current() + 1;
        for (uint256 i = 1; i < toPlanetId; i++) {
            totalPlanetsBalance += address(planet[i]).balance;
        }

        for (uint256 i = 1; i < toPlanetId; i++) {
            uint256 planetBalance = address(planet[i]).balance;
            if (planetBalance == 0) {
                planetBalance = 1;
            }

            uint256 balanceFactor = (planetBalance * 15000) /
                totalPlanetsBalance;

            uint256 orbit = balanceFactor;
            planetOrbit[i] = orbit;
        }
    }

    event PlanetCreated(uint256 id, address planetAddress);

    event StoreCreated(
        uint256 id,
        uint256 planetId,
        address storeAddress,
        Store.StoreType storeType
    );
}
