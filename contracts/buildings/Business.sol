// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Planet} from "../Planet.sol";
import {Galaxy} from "../Galaxy.sol";
import {Characters} from "../Characters.sol";
import {Resource} from "../resources/Resource.sol";

contract Business is Ownable {
    enum PredefinedBusinessType {
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
    uint256 public businessType;
    Galaxy public galaxy;

    constructor(
        uint256 _id,
        string memory _name,
        uint256 _planetId,
        uint256 _businessType
    ) {
        id = _id;
        name = _name;
        planetId = _planetId;
        galaxy = Galaxy(msg.sender);
        businessType = _businessType;
    }

    function produce(
        Resource resource,
        uint256 amount,
        address payable characterAddress,
        uint256 reward
    ) external onlyPlanet {
        require(characterAddress != address(0), "Invalid character address");
        require(resource.businessType() == uint(businessType), "Invalid resource business type for production");

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

        resource.produceForBusiness(amount);
    }

    modifier onlyPlanet() {
        uint256 _planetId = galaxy.addressToPlanetId(msg.sender);
        require(_planetId == planetId, "Caller is not the planet");
        _;
    }
}
