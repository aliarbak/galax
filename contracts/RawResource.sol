// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Planet} from "./Planet.sol";
import {Galaxy} from "./Galaxy.sol";
import {Characters} from "./Characters.sol";
import {Resource} from "./Resource.sol";
import {Store} from "./Store.sol";

contract RawResource is Resource {
    uint256 constant MAX_PRODUCTION_LIMIT = 1000;

    constructor(
        uint256 _id,
        string memory _name,
        string memory _symbol
    )
        Resource(
            _id,
            _name,
            _symbol,
            100 ether,
            uint(Store.StoreType.NONE),
            new ResourceCost[](0),
            MotiveCost(1, 1, 1),
            RequiredSkill(0, Characters.PredefinedSkillType.NONE)    
        )
    {}

    function produceForPlanet(uint256 amount) external override onlyPlanet {
        _mint(msg.sender, amount);
    }

    function calculateProductionCost(
        uint256 planetId,
        uint256 amount
    ) external view override returns (ProductionCost memory cost) {
        require(amount <= maxProductionLimit, "Out of max production limit");
        (
            uint256 hunger,
            uint256 thirstiness,
            uint256 energy
        ) = _calculateProductionMotiveCosts(amount);
        cost = ProductionCost(
            amount / 1000,
            hunger,
            thirstiness,
            energy,
            requiredSkill.skillFactor * amount,
            requiredSkill.skillType
        );
    }
}
