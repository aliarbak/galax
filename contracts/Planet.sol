// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Galaxy} from "./Galaxy.sol";
import {Characters} from "./Characters.sol";
import {Business} from "./buildings/Business.sol";
import {Resource} from "./resources/Resource.sol";

contract Planet is Ownable, ReentrancyGuard {
    uint256 private immutable _rawResourceId;

    uint256 public immutable id;
    uint256 public characterCount = 0;
    uint256 public businessCount = 0;
    string public name;
    string public baseUri;

    Galaxy public immutable galaxy;
    Characters public immutable characters;

    constructor(
        uint256 _id,
        string memory _baseUri,
        string memory _name,
        Characters _characters
    ) payable {
        id = _id;
        baseUri = _baseUri;
        name = _name;
        galaxy = Galaxy(payable(msg.sender));
        _rawResourceId = galaxy.rawResourceId();
        characters = _characters;
    }

    function produceResource(
        address payable characterAddress,
        uint256 amount,
        uint256 reward,
        bytes calldata signature
    ) external nonReentrant onlyOwner {
        Resource resource = galaxy.resource(_rawResourceId);
        Resource.ProductionCost memory cost = resource.calculateProductionCost(
            id,
            amount
        );

        require(
            address(this).balance >= cost.price + reward,
            "Insufficient balance for production"
        );

        bool sent = payable(galaxy).send(cost.price);
        require(sent, "Failed to send the cost");

        if (reward > 0) {
            sent = characterAddress.send(reward);
            require(sent, "Failed to send reward");
        }

        characters.produce(
            characterAddress,
            cost.skillType,
            cost.skillExp,
            _rawResourceId,
            Characters.MotiveEffect(cost.hunger, cost.thirstiness, cost.energy),
            signature
        );

        resource.produceForPlanet(amount);
    }

    function produceResourceOnBusiness(
        uint256 businessId,
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
            cost.skillType,
            cost.skillExp,
            resourceId,
            Characters.MotiveEffect(cost.hunger, cost.thirstiness, cost.energy),
            signature
        );
        galaxy.business(businessId).produce(
            resource,
            amount,
            characterAddress,
            reward
        );
    }

    function createBusiness(
        string memory _name,
        uint256 businessType,
        address ownerAddress
    ) external payable onlyOwner returns (Business business) {
        business = galaxy.createBusiness{value: msg.value}(_name, businessType, ownerAddress);
        businessCount++;
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

    function setBaseUri(string memory _baseUri) external onlyOwner {
        baseUri = _baseUri;
    }

    receive() external payable { }

    fallback() external payable { }

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
