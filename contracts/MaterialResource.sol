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

contract MaterialResource is Resource {
    constructor(
        uint256 _id,
        string memory _name,
        string memory _symbol,
        uint256 _maxProductionLimit,
        uint _storeType,
        ResourceCost[] memory _resourceCosts,
        MotiveCost memory _motiveCost,
        RequiredSkill memory _requiredSkill
    )
        Resource(
            _id,
            _name,
            _symbol,
            _maxProductionLimit,
            _storeType,
            _resourceCosts,
            _motiveCost,
            _requiredSkill
        )
    {}

    function produceForStore(uint256 amount) external override {
        uint256 storeId = galaxy.addressToStoreId(msg.sender);
        require(storeId > 0, "Resource: caller is not store");

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
            0,
            hunger,
            thirstiness,
            energy,
            requiredSkill.skillFactor * amount,
            requiredSkill.skillType
        );
    }
}
