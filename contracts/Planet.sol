// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Galaxy} from "./Galaxy.sol";
import {Characters} from "./Characters.sol";
import {Store} from "./Store.sol";
import {Resource} from "./Resource.sol";

contract Planet is Ownable, ReentrancyGuard {
    uint256 public id;
    uint256 public characterCount = 0;
    uint256 public storeCount = 0;
    string public name;

    Galaxy public galaxy;
    Characters public characters;

    constructor(
        uint256 _id,
        string memory _name,
        Characters _characters
    ) payable {
        id = _id;
        name = _name;
        galaxy = Galaxy(msg.sender);
        characters = _characters;
    }

    function produceResource(
        address payable characterAddress,
        uint256 amount,
        uint256 reward,
        bytes calldata signature
    ) external nonReentrant onlyOwner {
        Resource resource = galaxy.rawResource();
        Resource.ProductionCost memory cost = resource.calculateProductionCost(
            id,
            amount
        );

        require(
            address(this).balance >= cost.price + reward,
            "Insufficient balance for production"
        );
        characters.produce(
            characterAddress,
            uint256(cost.skillType),
            Characters.MotiveEffect(cost.hunger, cost.thirstiness, cost.energy),
            signature
        );

        resource.produceForPlanet(amount);
        bool sent = payable(address(galaxy)).send(cost.price);
        require(sent, "Failed to send the cost");

        if (reward > 0) {
            sent = characterAddress.send(reward);
            require(sent, "Failed to send reward");
        }
    }

    function produceResourceOnStore(
        uint256 storeId,
        uint256 resourceId,
        uint256 amount,
        address payable characterAddress,
        uint256 reward,
        bytes calldata signature
    ) external nonReentrant onlyOwner {
        Resource resource = galaxy.resource(resourceId);
        Resource.ProductionCost memory cost = resource.calculateProductionCost(
            id,
            amount
        );
        characters.produce(
            characterAddress,
            uint256(cost.skillType),
            Characters.MotiveEffect(cost.hunger, cost.thirstiness, cost.energy),
            signature
        );
        galaxy.store(storeId).produce(
            resource,
            amount,
            characterAddress,
            reward
        );
    }

    function createStore(
        string memory _name,
        Store.StoreType storeType,
        address ownerAddress
    ) external onlyOwner returns (Store store) {
        store = galaxy.createStore(_name, storeType, ownerAddress);
        storeCount++;
    }

    function joinCharacter(
        address characterAddress,
        bytes calldata signature
    ) external onlyOwner {
        characters.joinByPlanet(characterAddress, signature);
        characterCount++;
    }

    function characterJoined() external onlyCharacters {
        characterCount++;
    }

    function characterLeft() external onlyCharacters {
        characterCount--;
    }

    modifier onlyGalaxy() {
        require(
            msg.sender == address(galaxy),
            "Planet: caller is not the galaxy"
        );
        _;
    }

    modifier onlyCharacters() {
        require(
            msg.sender == address(characters),
            "Planet: caller is not the characters"
        );
        _;
    }
}
