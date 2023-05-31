// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "erc721a/contracts/ERC721A.sol";
import {Galaxy} from "./../Galaxy.sol";
import {Characters} from "./../Characters.sol";
import {Business} from "./../buildings/Business.sol";
import {Planet} from "./../Planet.sol";

abstract contract Item is ERC721A, ReentrancyGuard {
    using ECDSA for bytes32;
    enum PropIndex {
        PLANET_ID,
        STORE_ID,
        TYPE_IDENTIFIER
    }

    struct SellInput {
        uint8 planetCommissionRate;
        uint256 businessId;
        uint256 nonce;
        uint256 quantity;
        uint256 price;
        bytes signature;
        bytes32[] parameters;
    }

    struct ItemMintInput {
        Business business;
        uint256 planetId;
        uint256 businessId;
        uint256 quantity;
        bytes32[] parameters;
    }

    uint public businessType;
    uint256 public id;
    uint8 public galaxyCommissionRate;
    Galaxy public galaxy;
    mapping(uint256 => mapping(uint256 => bytes32)) public props;
    mapping(uint256 => bool) public nonce;

    constructor(
        uint256 _id,
        uint8 _galaxyCommissionRate,
        string memory _name,
        string memory _symbol,
        uint _businessType
    ) ERC721A(_name, _symbol) {
        id = _id;
        businessType = _businessType;
        galaxyCommissionRate = _galaxyCommissionRate;
    }

    function sell(
        SellInput memory request
    ) external payable virtual nonReentrant {
        (uint256 characterId, uint256 planetId, , , , , ) = galaxy
            .characters()
            .character(msg.sender);

        require(characterId > 0, "Item: caller is not a character");

        uint totalPrice = request.price * request.quantity;
        require(msg.value >= totalPrice, "Item: insufficent price value");

        require(!nonce[request.nonce], "Item: nonce already used");
        nonce[request.nonce] = true;

        require(characterId > 0, "Item: caller is not a character");
        Business business = galaxy.business(request.businessId);
        require(business.planetId() == planetId, "Item: invalid business");

        Planet planet = galaxy.planet(planetId);
        _verifySignature(planet.owner(), request);

        require(
            galaxyCommissionRate + request.planetCommissionRate <= 100,
            "Item: Invalid commission rates"
        );

        uint256 businessEarning = totalPrice;
        if (galaxyCommissionRate > 0) {
            uint256 galaxyCommission = (totalPrice / 100) *
                galaxyCommissionRate;
            businessEarning -= galaxyCommission;
            bool sent = payable(address(galaxy)).send(galaxyCommission);
            require(sent, "Item: galaxy commission payment failed");
        }

        if (request.planetCommissionRate > 0) {
            uint256 planetCommission = (totalPrice / 100) *
                request.planetCommissionRate;
            businessEarning -= planetCommission;
            bool sent = payable(address(planet)).send(planetCommission);
            require(sent, "Item: planet commission payment failed");
        }

        if (businessEarning > 0) {
            bool sent = payable(address(business)).send(businessEarning);
            require(sent, "Item: business payment failed");
        }

        _mint(
            ItemMintInput(
                business,
                planetId,
                request.businessId,
                request.quantity,
                request.parameters
            )
        );
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        uint256 planetId = _getPropUInt256(tokenId, PropIndex.PLANET_ID);
        uint256 businessId = _getPropUInt256(tokenId, PropIndex.STORE_ID);
        uint256 typeIdentifier = _getPropUInt256(
            tokenId,
            PropIndex.TYPE_IDENTIFIER
        );
        string memory baseUri = galaxy.planet(planetId).baseUri();
        return
            bytes(baseUri).length != 0
                ? string(
                    abi.encodePacked(
                        baseUri,
                        "/tokens/",
                        _toString(tokenId),
                        "?typeIdentifier=",
                        _toString(typeIdentifier),
                        "&businessId=",
                        _toString(businessId)
                    )
                )
                : "";
    }

    function setGalaxy(Galaxy _galaxy) external {
        require(address(galaxy) == address(0), "can not set galaxy");
        galaxy = _galaxy;
    }

    function _getProp(
        uint256 tokenId,
        uint256 propIndex
    ) internal view returns (bytes32) {
        return props[tokenId][propIndex];
    }

    function _getPropUInt256(
        uint256 tokenId,
        uint256 propIndex
    ) internal view returns (uint256) {
        return uint256(_getProp(tokenId, propIndex));
    }

    function _getPropUInt256(
        uint256 tokenId,
        PropIndex propIndex
    ) internal view returns (uint256) {
        return uint256(_getProp(tokenId, uint256(propIndex)));
    }

    function _mintItems(
        address to,
        uint256 quantity
    ) internal returns (uint256 fromTokenId, uint256 toTokenId) {
        fromTokenId = _nextTokenId();
        _mint(to, quantity);
        toTokenId = _nextTokenId();
    }

    function _mint(ItemMintInput memory request) internal virtual;

    function _verifySignature(
        address planetOwnerAddress,
        SellInput memory request
    ) private view {
        bytes32 message = keccak256(
            abi.encodePacked(
                address(this),
                block.chainid,
                request.nonce,
                request.businessId,
                request.price,
                request.quantity,
                request.parameters
            )
        );
        address signer = message.toEthSignedMessageHash().recover(
            request.signature
        );
        require(signer == planetOwnerAddress, "Invalid signature");
    }

    modifier onlyCharacters() {
        require(
            msg.sender == address(galaxy.characters()),
            "Item: caller is not the characters"
        );
        _;
    }
}
