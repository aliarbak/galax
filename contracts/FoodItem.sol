// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Galaxy} from "./Galaxy.sol";
import {Store} from "./Store.sol";
import {Item} from "./Item.sol";
import {Planet} from "./Planet.sol";
import {ConsumableItem} from "./ConsumableItem.sol";
import {Resource} from "./Resource.sol";
import {Characters} from "./Characters.sol";

contract FoodItem is ConsumableItem {
    uint256 constant TWO_DAYS_IN_SECONDS = 172800;
    uint256 public resourceId;
    uint256 public resourceCostPerHungerFactorGwei;

    constructor(
        uint256 _id,
        uint8 _galaxyCommissionRate,
        string memory _name,
        string memory _symbol,
        uint256 _resourceId,
        uint256 _resourceCostPerHungerFactorGwei
    ) Item(_id, _galaxyCommissionRate, _name, _symbol, uint(Store.StoreType.RESTAURANT)) {
        galaxy = Galaxy(msg.sender);
        resourceId = _resourceId;
        resourceCostPerHungerFactorGwei = _resourceCostPerHungerFactorGwei;
    }

    function _mint(ItemMintInput memory request) internal override {
        require(request.parameters.length == 2, "FoodItem: Invalid parameters");
        uint256 hungerEffect = uint256(request.parameters[0]);
        uint256 typeIdentifier = uint256(request.parameters[1]);

        require(hungerEffect > 0 && hungerEffect <= 100 ether, "FoodItem: Invalid hunger factor");
        uint256 resourceCost = ((hungerEffect / 10000000000000) / resourceCostPerHungerFactorGwei) * request.quantity;
        require(resourceCost > 0, "FoodItem: Invalid resource cost");

        Resource resource = galaxy.resource(resourceId);
        resource.burnByItem(address(request.store), resourceCost);
        (uint256 fromTokenId, uint256 toTokenId) = _mintItems(msg.sender, request.quantity);
        uint256 expiryDate = ((block.timestamp + TWO_DAYS_IN_SECONDS) / 1000) * 1000;
        _setProps(fromTokenId, toTokenId, request.planetId, request.storeId, typeIdentifier, expiryDate, hungerEffect, 0, 0);
    }
}
