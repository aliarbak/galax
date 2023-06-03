// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Planet} from "./Planet.sol";
import {Galaxy} from "./Galaxy.sol";
import {Characters} from "./Characters.sol";
import {Resource} from "./resources/Resource.sol";
import {Business} from "./buildings/Business.sol";
import {Item} from "./items/Item.sol";
import {Food} from "./items/Food.sol";
import {MaterialResource} from "./resources/MaterialResource.sol";

contract Galaxy is ReentrancyGuard {
    struct GalaxyCosts {
        uint256 planetCreation;
    }

    using Counters for Counters.Counter;
    Counters.Counter private _planetIds;
    Counters.Counter private _businessIds;
    uint256 private _maxBusinessType = uint(Business.PredefinedBusinessType.VEHICLE_GALLERY);
    uint256 private _maxResourceId = 0;
    uint256 private _maxItemId = 0;

    mapping(uint256 => Planet) public planet;
    mapping(address => uint256) public addressToPlanetId;
    mapping(uint256 => uint256) public planetOrbit;

    mapping(uint256 => Resource) public resource;
    mapping(address => uint256) public addressToResourceId;

    mapping(uint256 => Item) public item;
    mapping(address => uint256) public addressToItemId;

    mapping(uint256 => Business) public business;
    mapping(address => uint256) public addressToBusinessId;

    string public name;
    GalaxyCosts public costs;
    Characters public immutable characters;
    uint256 public immutable rawResourceId;

    constructor(
        string memory _name,
        GalaxyCosts memory _costs,
        address[] memory resourceAddresses,
        address[] memory itemAddresses,
        uint256 _rawResourceId
    ) {
        name = _name;
        characters = new Characters();
        costs = _costs;

        _addResources(resourceAddresses);
        _addItems(itemAddresses);

        require(_rawResourceId > 0, "Invalid raw resource id");
        require(address(resource[_rawResourceId]) != address(0), "Raw resource does not exists with given id");
        rawResourceId = _rawResourceId;
    }

    function createPlanet(
        string memory planetName,
        string memory baseUri,
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
        _planet.transferOwnership(msg.sender);
        planetAddress = address(_planet);

        planet[id] = _planet;
        addressToPlanetId[planetAddress] = id;

        _calculateOrbits();
        emit PlanetCreated(id, planetAddress);
    }

    function createBusiness(
        string calldata _name,
        uint256 businessType,
        address ownerAddress
    ) external payable nonReentrant returns (Business _business) {
        uint256 planetId = addressToPlanetId[msg.sender];
        require(planetId > 0, "Caller is not a planet");

        uint256 businessCreationCost = calculateBusinessCreationCost(planetId);
        require(msg.value >= businessCreationCost, "Insufficent payment");
        require(uint(businessType) < _maxBusinessType, "Invalid business type");

        _businessIds.increment();
        uint256 businessId = _businessIds.current();

        _business = new Business(businessId, _name, planetId, businessType);
        _business.transferOwnership(ownerAddress);

        business[businessId] = _business;
        addressToBusinessId[address(_business)] = businessId;
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
        if (orbitDiff == 0) {
            return orbitDiff;
        }

        return ((block.timestamp + movingTimeInSec) / 1000) * 1000;
    }

    function calculateBusinessCreationCost(
        uint256 planetId
    ) public pure returns (uint256) {
        return 100000; // TO DO
    }

    receive() external payable { }

    fallback() external payable { }

    function _addItems(address[] memory itemAddressess) private {
        for (uint256 i = 0; i < itemAddressess.length; i++) {
            _addItem(itemAddressess[i]);
        }
    }

    function _addItem(address itemAddress) private {
        Item _item = Item(itemAddress);
        address itemGalaxyAddress = address(_item.galaxy());
        require(
            itemGalaxyAddress == address(this) ||
                itemGalaxyAddress == address(0),
            "Galaxy: invalid item galaxy address"
        );

        uint256 itemId = _item.id();
        require(itemId == _maxItemId + 1, "Invalid item id");

        addressToItemId[itemAddress] = itemId;
        item[itemId] = _item;
        _maxItemId = itemId;

        if (itemGalaxyAddress == address(0)) {
            _item.setGalaxy(this);
        }
    }

    function _addResources(address[] memory resourceAddresses) private {
        for (uint256 i = 0; i < resourceAddresses.length; i++) {
            _addResource(resourceAddresses[i]);
        }
    }

    function _addResource(address resourceAddress) private {
        Resource _resource = Resource(resourceAddress);
        address resourceGalaxyAddress = address(_resource.galaxy());
        require(
            resourceGalaxyAddress == address(this) ||
                resourceGalaxyAddress == address(0),
            "Galaxy: invalid resource galaxy address"
        );
        if (resourceGalaxyAddress == address(0)) {
            _resource.setGalaxy(this);
        }

        uint256 resourceId = _resource.id();
        require(resourceId == _maxResourceId + 1, "Invalid resource id");

        addressToResourceId[resourceAddress] = resourceId;
        resource[resourceId] = _resource;
        _maxResourceId = resourceId;    
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

    event BusinessCreated(
        uint256 id,
        uint256 planetId,
        address businessAddress,
        uint256 businessType
    );
}
