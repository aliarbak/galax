// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Planet} from "./Planet.sol";
import {Galaxy} from "./Galaxy.sol";
import {Characters} from "./Characters.sol";
import {Resource} from "./Resource.sol";

contract Store is Ownable {
    enum StoreType {
        NONE,
        RESTAURANT,
        GROCERY_STORE,
        FMCG_MANUFACTURER,
        VEHICLE_MANUFACTURER,
        VEHICLE_GALLERY
    }

    uint256 public id;
    uint256 public planetId;
    string public name;
    StoreType public storeType;
    Galaxy public galaxy;

    constructor(
        uint256 _id,
        string memory _name,
        uint256 _planetId,
        StoreType _storeType
    ) {
        id = _id;
        name = _name;
        planetId = _planetId;
        galaxy = Galaxy(msg.sender);
        storeType = _storeType;
    }

    function produce(
        Resource resource,
        uint256 amount,
        address payable characterAddress,
        uint256 reward
    ) external onlyPlanet {
        require(resource.storeType() == uint(storeType), "Invalid resource store type for production");

        Resource.ResourceCost[] memory costs = resource
            .calculateProductionResourceCosts(amount);

        for (uint256 i = 0; i < costs.length; i++) {
            Resource costResource = galaxy.resource(costs[i].id);
            costResource.burn(costs[i].amount);
        }

        if (reward > 0) {
            bool sent = characterAddress.send(reward);
            require(sent, "Failed to send reward");
        }

        resource.produceForStore(amount);
    }

    modifier onlyPlanet() {
        uint256 _planetId = galaxy.addressToPlanetId(msg.sender);
        require(_planetId == planetId, "Caller is not the planet");
        _;
    }
}
