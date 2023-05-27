// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Planet} from "./Planet.sol";
import {Galaxy} from "./Galaxy.sol";
import {Characters} from "./Characters.sol";
import {Store} from "./Store.sol";

abstract contract Resource is ERC20, ReentrancyGuard {
    struct ResourceCost {
        uint256 id;
        uint256 amount;
    }

    struct MotiveCost {
        uint16 hunger;
        uint16 thirstiness;
        uint16 energy;
    }

    struct RequiredSkill {
        uint256 skillRate;
        Characters.PredefinedSkillType skillType;
    }

    struct ProductionCost {
        uint256 hunger;
        uint256 thirstiness;
        uint256 energy;
        uint256 price;
        uint256 skillExp;
        Characters.PredefinedSkillType skillType;
    }

    struct StakedTransfer {
        address from;
        address to;
        uint256 amount;
        uint256 arrivalTime;
    }

    uint256 public id;
    uint256 public maxProductionLimit;
    StakedTransfer[] public stakedTransfers;
    ResourceCost[] public resourceCosts;
    MotiveCost public motiveCost;
    RequiredSkill public requiredSkill;
    Galaxy public galaxy;

    constructor(
        uint256 _id,
        string memory _name,
        string memory _symbol,
        uint256 _maxProductionLimit,
        ResourceCost[] memory _resourceCosts,
        MotiveCost memory _motiveCost,
        RequiredSkill memory _requiredSkill
    ) ERC20(_name, _symbol) {
        id = _id;
        galaxy = Galaxy(msg.sender);
        motiveCost = _motiveCost;
        requiredSkill = _requiredSkill;
        maxProductionLimit = _maxProductionLimit;
        for (uint256 i = 0; i < _resourceCosts.length; i++) {
            resourceCosts.push(_resourceCosts[i]);
        }
    }

    function produceForStore(uint256 amount) external virtual {
        revert("can not produce for store");
    }

    function produceForPlanet(uint256 amount) external virtual {
        revert("can not produce for planet");
    }

    function calculateProductionCost(
        uint256 planetId,
        uint256 amount
    ) external view virtual returns (ProductionCost memory cost);

    function calculateProductionResourceCosts(
        uint256 amount
    ) external view virtual returns (ResourceCost[] memory costs) {
        costs = new ResourceCost[](resourceCosts.length);
        for (uint256 i = 0; i < resourceCosts.length; i++) {
            costs[i].id = resourceCosts[i].id;
            costs[i].amount = resourceCosts[i].amount * amount;
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);

        uint256 fromPlanetId = galaxy.addressToPlanetId(from);
        if (fromPlanetId > 0) {
            return _transferFromPlanet(fromPlanetId, from, to, amount);
        }

        uint256 fromStoreId = galaxy.addressToStoreId(from);
        if (fromStoreId > 0) {
            return _transferFromStore(fromPlanetId, from, to, amount);
        }

        revert("Unknown receiver");
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address from = _msgSender();
        uint256 fromPlanetId = galaxy.addressToPlanetId(from);
        if (fromPlanetId > 0) {
            return _transferFromPlanet(fromPlanetId, from, to, amount);
        }

        uint256 fromStoreId = galaxy.addressToStoreId(from);
        if (fromStoreId > 0) {
            return _transferFromStore(fromPlanetId, from, to, amount);
        }

        revert("Unknown receiver");
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function tick() external nonReentrant {
        for (uint256 i = 0; i < stakedTransfers.length; i++) {
            if (block.timestamp < stakedTransfers[i].arrivalTime) {
                continue;
            }

            address to = stakedTransfers[i].to;
            uint256 amount = stakedTransfers[i].amount;
            stakedTransfers[i] = stakedTransfers[stakedTransfers.length - 1];
            stakedTransfers.pop();
            _transfer(address(this), to, amount);
        }
    }

    function _calculateProductionMotiveCosts(
        uint256 amount
    )
        internal
        view
        virtual
        returns (uint256 hunger, uint256 thirstiness, uint256 energy)
    {
        hunger = motiveCost.hunger * amount;
        if (hunger > 100 ether) {
            hunger = 100 ether;
        }

        thirstiness = motiveCost.thirstiness * amount;
        if (thirstiness > 100 ether) {
            thirstiness = 100 ether;
        }

        energy = motiveCost.energy * amount;
        if (energy > 100 ether) {
            energy = 100 ether;
        }
    }

    function _transferFromPlanet(
        uint256 fromPlanetId,
        address from,
        address to,
        uint256 amount
    ) internal virtual returns (bool) {
        uint256 toPlanetId = galaxy.addressToPlanetId(to);
        if (toPlanetId > 0) {
            uint256 arrivalTimeToPlanet = galaxy.calculateArrivalTimeToPlanet(
                fromPlanetId,
                toPlanetId
            );
            _transfer(from, address(this), amount);
            stakedTransfers.push(
                StakedTransfer(from, to, amount, arrivalTimeToPlanet)
            );
            return true;
        }

        uint256 toStoreId = galaxy.addressToStoreId(to);
        if (toStoreId > 0) {
            Store store = Store(to);
            require(store.planetId() == fromPlanetId, "Invalid store planet");
            _transfer(from, to, amount);
            return true;
        }

        revert("Unknown receiver");
    }

    function _transferFromStore(
        uint256 fromStoreId,
        address from,
        address to,
        uint256 amount
    ) internal virtual returns (bool) {
        Store store = galaxy.store(fromStoreId);
        uint256 toPlanetId = galaxy.addressToPlanetId(to);
        if (toPlanetId > 0) {
            require(store.planetId() == toPlanetId, "Invalid receiver planet");
            _transfer(from, to, amount);
            return true;
        }

        uint256 toStoreId = galaxy.addressToStoreId(to);
        if (toStoreId > 0) {
            Store toStore = Store(to);
            require(
                store.planetId() == toStore.planetId(),
                "Invalid receiver store"
            );
            _transfer(from, to, amount);
            return true;
        }

        revert("Unknown receiver");
    }

    modifier onlyCharacters() {
        Characters characters = galaxy.characters();
        require(
            address(characters) == msg.sender,
            "Resource: caller is not characters"
        );
        _;
    }

    modifier onlyPlanet() {
        uint256 planetId = galaxy.addressToPlanetId(msg.sender);
        require(planetId > 0, "Resource: caller is not planet");
        _;
    }

    event TransferStaked(
        address from,
        address to,
        uint256 amount,
        uint256 arrivalTime
    );
}
