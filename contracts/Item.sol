// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "erc721a/contracts/ERC721A.sol";
import {Galaxy} from "./Galaxy.sol";
import {Characters} from "./Characters.sol";
import {Store} from "./Store.sol";
import {Planet} from "./Planet.sol";

abstract contract Item is ERC721A, ReentrancyGuard {
    using ECDSA for bytes32;
    enum PropIndex {
        PLANET_ID,
        STORE_ID,
        TYPE_IDENTIFIER
    }

    struct SellInput {
        uint8 planetCommissionRate;
        uint256 storeId;
        uint256 nonce;
        uint256 quantity;
        uint256 price;
        bytes signature;
        bytes32[] parameters;
    }

    struct ItemMintInput {
        Store store;
        uint256 planetId;
        uint256 storeId;
        uint256 quantity;
        bytes32[] parameters;
    }

    uint public storeType;
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
        uint _storeType
    ) ERC721A(_name, _symbol) {
        id = _id;
        storeType = _storeType;
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

        require(nonce[request.nonce] == false, "Item: nonce already used");
        nonce[request.nonce] = true;

        require(characterId > 0, "Item: caller is not a character");
        Store store = galaxy.store(request.storeId);
        require(store.planetId() == planetId, "Item: invalid store");

        Planet planet = galaxy.planet(planetId);
        _verifySignature(planet.owner(), request);

        require(
            galaxyCommissionRate + request.planetCommissionRate <= 100,
            "Item: Invalid commission rates"
        );

        uint256 storeEarning = totalPrice;
        if (galaxyCommissionRate > 0) {
            uint256 galaxyCommission = (totalPrice / 100) *
                galaxyCommissionRate;
            storeEarning -= galaxyCommission;
            bool sent = payable(address(galaxy)).send(galaxyCommission);
            require(sent, "Item: galaxy commission payment failed");
        }

        if (request.planetCommissionRate > 0) {
            uint256 planetCommission = (totalPrice / 100) *
                request.planetCommissionRate;
            storeEarning -= planetCommission;
            bool sent = payable(address(planet)).send(planetCommission);
            require(sent, "Item: planet commission payment failed");
        }

        if (storeEarning > 0) {
            bool sent = payable(address(store)).send(storeEarning);
            require(sent, "Item: store payment failed");
        }

        _mint(
            ItemMintInput(
                store,
                planetId,
                request.storeId,
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
        uint256 storeId = _getPropUInt256(tokenId, PropIndex.STORE_ID);
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
                        "&storeId=",
                        _toString(storeId)
                    )
                )
                : "";
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
                request.storeId,
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
