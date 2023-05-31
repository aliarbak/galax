// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Galaxy} from "./Galaxy.sol";
import {Planet} from "./Planet.sol";
import {Resource} from "./resources/Resource.sol";

contract Characters is ReentrancyGuard {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    struct Character {
        uint256 id;
        uint256 planetId;
        uint256 nonce;
        uint256 hunger;
        uint256 thirstiness;
        uint256 energy;
        uint256 arrivalTimeToPlanet;
    }

    struct MotiveEffect {
        uint256 hunger;
        uint256 thirstiness;
        uint256 energy;
    }

    enum PredefinedSkillType {
        NONE,
        COOKING,
        MANUFACTURING,
        MECHANIC
    }

    enum SignatureType {
        NONE,
        JOIN,
        PRODUCE
    }

    uint256 constant DEFAULT_MOTIVE = 70 ether;
    Counters.Counter private _ids;

    mapping(uint256 => address) public characterIdToAddress;
    mapping(address => Character) public character;
    mapping(address => mapping(uint => uint256)) public characterSkill;

    Galaxy public galaxy;

    constructor() {
        galaxy = Galaxy(msg.sender);
    }

    function produce(
        address characterAddress,
        uint skill,
        MotiveEffect memory motiveEffect,
        bytes calldata signature
    ) external payable nonReentrant {
        uint256 planetId = galaxy.addressToPlanetId(address(msg.sender));
        require(planetId > 0, "Caller is not a planet");

        Character memory _character = _getArrivedCharacter(
            characterAddress,
            planetId
        );
        _verifySignature(
            characterAddress,
            planetId,
            _character.nonce,
            SignatureType.PRODUCE,
            signature
        );
        _reduceMotives(
            characterAddress,
            motiveEffect.hunger,
            motiveEffect.thirstiness,
            motiveEffect.energy
        );
        _increaseNonce(characterAddress);
        characterSkill[characterAddress][skill]++;
        _character = character[characterAddress];
        emit Produced(
            characterAddress,
            skill,
            characterSkill[characterAddress][skill],
            _character.hunger,
            _character.thirstiness,
            _character.energy
        );
    }

    function joinToPlanet(
        uint256 planetId
    ) external nonReentrant returns (uint256 arrivalTimeToPlanet) {
        _getOrCreateCharacter(msg.sender);
        arrivalTimeToPlanet = _joinPlanet(msg.sender, planetId);
        galaxy.planet(planetId).characterJoined();
    }

    function joinByPlanet(
        address characterAddress,
        bytes calldata signature
    ) external nonReentrant returns (uint256 arrivalTimeToPlanet) {
        uint256 planetId = galaxy.addressToPlanetId(msg.sender);
        require(planetId > 0, "Caller is not a planet");

        Character memory _character = _getOrCreateCharacter(characterAddress);
        _verifySignature(
            characterAddress,
            planetId,
            _character.nonce,
            SignatureType.JOIN,
            signature
        );

        return _joinPlanet(characterAddress, planetId);
    }

    function _getArrivedCharacter(
        address characterAddress,
        uint256 planetId
    ) private view returns (Character memory) {
        Character memory _character = character[characterAddress];
        require(_character.id > 0, "Character does not exist");
        _checkArrivedCharacter(_character, planetId);
        return _character;
    }

    function _getOrCreateCharacter(
        address characterAddress
    ) private returns (Character memory) {
        Character memory _character = character[characterAddress];
        if (_character.id > 0) {
            return _character;
        }

        _ids.increment();
        uint256 id = _ids.current();
        character[characterAddress] = Character(
            id,
            0,
            1,
            DEFAULT_MOTIVE,
            DEFAULT_MOTIVE,
            DEFAULT_MOTIVE,
            0
        );
        characterIdToAddress[id] = characterAddress;
        return character[characterAddress];
    }

    function _verifySignature(
        address characterAddress,
        uint256 planetId,
        uint256 nonce,
        SignatureType signatureType,
        bytes calldata signature
    ) private view {
        bytes32 message = keccak256(
            abi.encodePacked(
                address(this),
                block.chainid,
                characterAddress,
                planetId,
                nonce,
                uint(signatureType)
            )
        );

        address signer = message.toEthSignedMessageHash().recover(signature);
        require(signer == characterAddress, "Invalid signature");
    }

    function _increaseNonce(address characterAddress) private {
        uint256 nonce = character[characterAddress].nonce;
        character[characterAddress].nonce = nonce + block.timestamp / 1000;
    }

    function _reduceMotives(
        address characterAddress,
        uint256 hunger,
        uint256 thirstiness,
        uint256 energy
    ) private {
        require(
            character[characterAddress].hunger >= hunger,
            "Insufficent hunger"
        );
        require(
            character[characterAddress].thirstiness >= thirstiness,
            "Insufficent thirstiness"
        );
        require(
            character[characterAddress].energy >= energy,
            "Insufficent energy"
        );

        character[characterAddress].hunger -= hunger;
        character[characterAddress].thirstiness -= thirstiness;
        character[characterAddress].energy -= energy;
    }

    function _joinPlanet(
        address characterAddress,
        uint256 planetId
    ) private returns (uint256 arrivalTimeToPlanet) {
        require(
            character[characterAddress].planetId != planetId,
            "Character is already in this planet"
        );
        require(
            character[characterAddress].arrivalTimeToPlanet < block.timestamp,
            "Character is already moving to a planet"
        );

        Planet planet = galaxy.planet(planetId);
        require(address(planet) != address(0), "Invalid planet");

        uint256 fromPlanetId = character[characterAddress].planetId;
        arrivalTimeToPlanet = galaxy.calculateArrivalTimeToPlanet(
            fromPlanetId,
            planetId
        );

        character[characterAddress].planetId = planetId;
        character[characterAddress].arrivalTimeToPlanet = arrivalTimeToPlanet;

        _increaseNonce(characterAddress);
        if (fromPlanetId > 0) {
            galaxy.planet(fromPlanetId).characterLeft();
        }
        
        emit JoinedToPlanet(
            characterAddress,
            fromPlanetId,
            planetId,
            arrivalTimeToPlanet
        );
    }

    function _checkArrivedCharacter(
        Character memory _character,
        uint256 planetId
    ) private view {
        require(
            _character.planetId == planetId,
            "Character is not on the planet"
        );
        require(
            _character.arrivalTimeToPlanet < block.timestamp,
            "Character is on the move"
        );
    }

    function tick() external nonReentrant {
        if (address(this).balance > 0) {
            bool sent = payable(address(galaxy)).send(address(this).balance);
            require(sent, "Failed to send the balance");
        }
    }

    modifier onlyPlanet() {
        require(
            galaxy.addressToPlanetId(msg.sender) > 0,
            "Caller is not a planet"
        );
        _;
    }

    event JoinedToPlanet(
        address characterAddress,
        uint256 fromPlanetId,
        uint256 toPlanetId,
        uint256 arrivalTimeToPlanet
    );

    event Produced(
        address characterAddress,
        uint skill,
        uint256 skillExp,
        uint256 hunger,
        uint256 thirstiness,
        uint256 energy
    );
}
