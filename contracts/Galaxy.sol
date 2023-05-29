// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Planet} from "./Planet.sol";
import {Galaxy} from "./Galaxy.sol";
import {Characters} from "./Characters.sol";
import {Resource} from "./Resource.sol";
import {Store} from "./Store.sol";
import {RawResource} from "./RawResource.sol";
import {Item} from "./Item.sol";
import {FoodItem} from "./FoodItem.sol";
import {MaterialResource} from "./MaterialResource.sol";

contract Galaxy is ReentrancyGuard {
    struct GalaxyCosts {
        uint256 planetCreation;
    }

    using Counters for Counters.Counter;
    Counters.Counter private _planetIds;
    Counters.Counter private _storeIds;
    Counters.Counter private _resourceIds;
    Counters.Counter private _itemIds;

    mapping(uint256 => Planet) public planet;
    mapping(address => uint256) public addressToPlanetId;
    mapping(uint256 => uint256) public planetOrbit;

    mapping(uint256 => Resource) public resource;
    mapping(address => uint256) public addressToResourceId;
    Resource[] public resources;

    mapping(uint256 => Item) public item;
    mapping(address => uint256) public addressToItemId;

    mapping(uint256 => Store) public store;
    mapping(address => uint256) public addressToStoreId;

    RawResource public rawResource;
    Characters public characters;
    GalaxyCosts public costs;
    string public name;

    constructor(
        string memory _name
    ) {
        name = _name;
        characters = new Characters();
        costs = GalaxyCosts(1000000); // TO DO

        _createInitialResources();
        _createInitialItems();
    }

    function createPlanet(
        string calldata planetName,
        string calldata baseUri,
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
            baseUri,
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

    function _createInitialResources() private {
        _createRawResource("Galax Raw Resource", "GXRR");

        Resource.ResourceCost[]
            memory foodResourceCosts = new Resource.ResourceCost[](1);
        foodResourceCosts[0] = Resource.ResourceCost(1, 100);
        _createMaterialResource(
            "Galax Foods and Drinks Resource",
            "GFDR",
            100,
            Store.StoreType.RESTAURANT,
            foodResourceCosts,
            Resource.MotiveCost(1 ether, 1 ether, 1 ether),
            Resource.RequiredSkill(1, Characters.PredefinedSkillType.COOKING)
        );

         Resource.ResourceCost[]
            memory fmcgResourceCosts = new Resource.ResourceCost[](1);
        fmcgResourceCosts[0] = Resource.ResourceCost(1, 100);
        _createMaterialResource(
            "Galax FMCG Resource",
            "GXFR",
            100,
            Store.StoreType.FMCG_MANUFACTURER,
            fmcgResourceCosts,
            Resource.MotiveCost(1 ether, 1 ether, 1 ether),
            Resource.RequiredSkill(1, Characters.PredefinedSkillType.MANUFACTURING)
        );

        Resource.ResourceCost[]
            memory vehicleResourceCosts = new Resource.ResourceCost[](1);
        vehicleResourceCosts[0] = Resource.ResourceCost(1, 100);
        _createMaterialResource(
            "Galax Vehicle Resource",
            "GXVR",
            100,
            Store.StoreType.VEHICLE_MANUFACTURER,
            vehicleResourceCosts,
            Resource.MotiveCost(1 ether, 1 ether, 1 ether),
            Resource.RequiredSkill(1, Characters.PredefinedSkillType.MECHANIC)
        );
    }   

    function _createInitialItems() private {
        _itemIds.increment();
        uint256 foodItemId = _itemIds.current();
        FoodItem foodItem = new FoodItem(foodItemId, 10, "Galax Food Item", "GXFI", 2, 10); // TO DO
        item[foodItemId] = foodItem;
        addressToItemId[address(foodItem)] = foodItemId;
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

    function _createMaterialResource(
        string memory resourceName,
        string memory resourceSymbol,
        uint256 maxProductionLimit,
        Store.StoreType storeType,
        Resource.ResourceCost[] memory resourceCosts,
        Resource.MotiveCost memory motiveCost,
        Resource.RequiredSkill memory requiredSkill
    ) private {
        _resourceIds.increment();
        uint256 resourceId = _resourceIds.current();
        MaterialResource _resource = new MaterialResource(
            resourceId,
            resourceName,
            resourceSymbol,
            maxProductionLimit,
            uint(storeType),
            resourceCosts,
            motiveCost,
            requiredSkill
        );

        resource[resourceId] = _resource;
        addressToResourceId[address(_resource)] = resourceId;
        resources.push(_resource);
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
