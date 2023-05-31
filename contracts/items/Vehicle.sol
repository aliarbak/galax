// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "erc721a/contracts/ERC721A.sol";
import {Item} from "./Item.sol";
import {Business} from "./../buildings/Business.sol";
import {Galaxy} from "./../Galaxy.sol";
import {Resource} from "./../resources/Resource.sol";

contract Vehicle is Item {
    uint256 public resourceId;
    mapping(uint256 => uint256) public vehicleModelResourceCost;
    mapping(uint256 => mapping(uint256 => uint256)) public vehiclePropValueResourceCost;

    constructor(
        uint256 _id,
        uint8 _galaxyCommissionRate,
        string memory _name,
        string memory _symbol,
        uint256 _resourceId,
        VehicleModelInput[] memory models,
        VehicleProp[] memory props
    )
        Item(
            _id,
            _galaxyCommissionRate,
            _name,
            _symbol,
            uint(Business.PredefinedBusinessType.VEHICLE_GALLERY)
        )
    {
        resourceId = _resourceId;

        for(uint256 i = 0; i < models.length; i++) {
            vehicleModelResourceCost[models[i].typeIdentifier] = models[i].resourceCost;
        }

          for(uint256 i = 0; i < props.length; i++) {
            for(uint256 j = 0; j < props[i].values.length; j++) {
                vehiclePropValueResourceCost[props[i].index][props[i].values[j].value] = props[i].values[j].resourceCost;
            }
        }
    }

    function _mint(ItemMintInput memory request) internal override {
        require(request.parameters.length == 3, "Vehicle: Invalid parameters");
        uint256 typeIdentifier = uint256(request.parameters[0]);
        uint256 primaryColor = uint256(request.parameters[1]);
        uint256 secondaryColor = uint256(request.parameters[2]);

        uint256 resourceCost = vehicleModelResourceCost[typeIdentifier] * request.quantity;
        require(resourceCost > 0, "Vehicle: Invalid type identifier");

        Resource resource = galaxy.resource(resourceId);
        resource.burnByItem(address(request.business), resourceCost);
        (uint256 fromTokenId, uint256 toTokenId) = _mintItems(
            msg.sender,
            request.quantity
        );

        _setInitialProps(
            fromTokenId,
            toTokenId,
            request.planetId,
            request.businessId,
            typeIdentifier,
            primaryColor,
            secondaryColor
        );
    }

    function _setPropValue(
        uint256 tokenId,
        VehiclePropIndex propIndex,
        uint256 value
    ) internal returns (uint256 resourceCost) {
        resourceCost = vehiclePropValueResourceCost[uint(propIndex)][value];
        require(resourceCost > 0, "Vehicle: Invalid prop value");
        props[tokenId][uint(propIndex)] = bytes32(value);
    }

    function _setInitialProps(
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 planetId,
        uint256 businessId,
        uint256 typeIdentifier,
        uint256 primaryColor,
        uint256 secondaryColor
    ) internal {
        for (uint256 tokenId = fromTokenId; tokenId < toTokenId; tokenId++) {
            _setInitialProps(
                tokenId,
                planetId,
                businessId,
                typeIdentifier,
                primaryColor,
                secondaryColor
            );
        }
    }

    function _setInitialProps(
        uint256 tokenId,
        uint256 planetId,
        uint256 businessId,
        uint256 typeIdentifier,
        uint256 primaryColor,
        uint256 secondaryColor
    ) internal {
        props[tokenId][uint(VehiclePropIndex.PLANET_ID)] = bytes32(planetId);
        props[tokenId][uint(VehiclePropIndex.STORE_ID)] = bytes32(businessId);
        props[tokenId][uint(VehiclePropIndex.TYPE_IDENTIFIER)] = bytes32(
            typeIdentifier
        );

        _setPropValue(tokenId, VehiclePropIndex.PRIMARY_COLOR, primaryColor);
        _setPropValue(
            tokenId,
            VehiclePropIndex.SECONDARY_COLOR,
            secondaryColor
        );
    }

    enum VehiclePropIndex {
        PLANET_ID,
        STORE_ID,
        TYPE_IDENTIFIER,
        SPOILERS,
        FRONT_BUMPER,
        REAR_BUMPER,
        SIDE_SKIRT,
        EXHAUST,
        FRAME,
        GRILLE,
        BONNET,
        LEFT_WING,
        RIGHT_WING,
        ROOF,
        ENGINE,
        BRAKES,
        TRANSMISSION,
        HORNS,
        SUSPENSION,
        ARMOR,
        UNKNOWN_17,
        TURBO,
        UNKNOWN_19,
        CUSTOM_TIRE_SMOKE,
        UNKNOWN_21,
        XENON,
        FRONT_WHEELS,
        BACK_WHEELS,
        PLATE_HOLDERS,
        PLATE_VANITY,
        TRIM_DESIGN,
        ORNAMENTS,
        DIAL_DESIGN,
        DOOR_INTERIOR,
        SEATS,
        STEERING_WHEEL,
        SHIFT_LEVER,
        PLAQUES,
        REAR_SHELF,
        TRUNK,
        HYDRAULICS,
        ENGINE_BLOCK,
        AIR_FILTER,
        STRUT_BAR,
        ARCH_COVER,
        ANTENNA,
        EXTERIOR_PARTS,
        TANK,
        DOOR_WINDOWS,
        WHEELS_REAR_OR_HYDRAULICS,
        LIVERY,
        PRIMARY_COLOR,
        SECONDARY_COLOR
    }

    struct VehicleModelInput {
        uint256 typeIdentifier;
        uint256 resourceCost;
    }

    struct VehicleProp {
        uint256 index;
        VehiclePropValue[] values;
    }

    struct VehiclePropValue {
        uint256 value;
        uint256 resourceCost;
    }
}
