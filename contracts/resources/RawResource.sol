// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Planet} from "./../Planet.sol";
import {Galaxy} from "./../Galaxy.sol";
import {Characters} from "./../Characters.sol";
import {Resource} from "./Resource.sol";
import {Business} from "./../buildings/Business.sol";

contract RawResource is Resource {
    constructor(
        uint256 _id,
        string memory _name,
        string memory _symbol
    )
        Resource(
            _id,
            _name,
            _symbol,
            1 ether,
            uint(Business.PredefinedBusinessType.NONE),
            new ResourceCost[](0),
            MotiveCost(1, 1, 1),
            RequiredSkill(1000000, uint(Characters.PredefinedSkillType.RAW_PRODUCTION))
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
            hunger * 100,
            thirstiness * 100,
            energy * 100,
            amount / 1000,
            amount / requiredSkill.skillFactor,
            requiredSkill.skillType
        );
    }
}
