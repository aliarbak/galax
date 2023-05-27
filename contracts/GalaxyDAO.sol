// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Resource} from "./Resource.sol";

abstract contract GalaxyDAO {
    enum ProposalType {
        NONE,
        MATERIAL_RESOURCE
    }

    struct Proposal {
        uint256 id;
        uint256 endingAt;
        ProposalType proposalType;
        address proposer;
    }

    struct ResourceProposal {
        string symbol;
        string name;
        Resource.ResourceCost[] resourceCosts;
    }

    mapping(uint256 => Proposal) public proposal;
}
