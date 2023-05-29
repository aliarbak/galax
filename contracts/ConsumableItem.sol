// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Characters} from "./Characters.sol";
import {Item} from "./Item.sol";

abstract contract ConsumableItem is Item {
    enum ConsumableItemPropIndex {
        PLANET_ID,
        STORE_ID,
        TYPE_IDENTIFIER,
        EXPIRY_DATE,
        HUNGER_EFFECT,
        THIRSTINESS_EFFECT,
        ENERGY_EFFECT
    }

    function consume(
        address characterAddress,
        uint256 tokenId
    ) external onlyCharacters returns (Characters.MotiveEffect memory effect) {
        require(
            ownerOf(tokenId) == characterAddress,
            "ConsumeableItem: Invalid owner"
        );

        uint256 expiryDate = uint256(
            props[tokenId][uint(ConsumableItemPropIndex.EXPIRY_DATE)]
        );

        require(expiryDate < block.timestamp, "ConsumeableItem: Expired food");
        effect = Characters.MotiveEffect(
            uint256(props[tokenId][uint(ConsumableItemPropIndex.HUNGER_EFFECT)]),
            uint256(props[tokenId][uint(ConsumableItemPropIndex.THIRSTINESS_EFFECT)]),
            uint256(props[tokenId][uint(ConsumableItemPropIndex.ENERGY_EFFECT)])
        );

        _burn(tokenId, false);
        return effect;
    }

    function _setProps(
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 planetId,
        uint256 storeId,
        uint256 typeIdentifier,
        uint256 expiryDate,
        uint256 hungerEffect,
        uint256 thirstinessEffect,
        uint256 energyEffect
    ) internal {
        for (uint256 tokenId = fromTokenId; tokenId < toTokenId; tokenId++) {
            _setProps(
                tokenId,
                planetId,
                storeId,
                typeIdentifier,
                expiryDate,
                hungerEffect,
                thirstinessEffect,
                energyEffect
            );
        }
    }

    function _setProps(
        uint256 tokenId,
        uint256 planetId,
        uint256 storeId,
        uint256 typeIdentifier,
        uint256 expiryDate,
        uint256 hungerEffect,
        uint256 thirstinessEffect,
        uint256 energyEffect
    ) internal {
        props[tokenId][uint(ConsumableItemPropIndex.PLANET_ID)] = bytes32(
            planetId
        );
        props[tokenId][uint(ConsumableItemPropIndex.STORE_ID)] = bytes32(
            storeId
        );
        props[tokenId][uint(ConsumableItemPropIndex.TYPE_IDENTIFIER)] = bytes32(
            typeIdentifier
        );
        props[tokenId][uint(ConsumableItemPropIndex.EXPIRY_DATE)] = bytes32(
            expiryDate
        );
        props[tokenId][uint(ConsumableItemPropIndex.HUNGER_EFFECT)] = bytes32(
            hungerEffect
        );
        props[tokenId][
            uint(ConsumableItemPropIndex.THIRSTINESS_EFFECT)
        ] = bytes32(thirstinessEffect);
        props[tokenId][uint(ConsumableItemPropIndex.ENERGY_EFFECT)] = bytes32(
            energyEffect
        );
    }
}
