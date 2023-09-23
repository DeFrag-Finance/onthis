//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "./interfaces/IGMX.sol";
import "./interfaces/IGMXPositionRouter.sol";
import "./interfaces/IChainlinkPriceOracle.sol";
import "./interfaces/IGMXVault.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IUsdc.sol";
import "hardhat/console.sol";

contract L2GmxProxy is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    event RequestCreated(bytes32 reqId);
    event CancelRequestCreated(bytes32 reqId);

    struct Position {
        address maker;
        bool isConfirmed;
        bool isOpenRequest;
        bool isLong;
        uint256 sizeDelta;
    }

    address public constant GMX_POSITION_ROUTER =
        0xb87a436B93fFE9D75c5cFA7bAcFff96430b09868;
    address public constant GMX_ROUTER =
        0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064;
    address public constant GMX_VAULT =
        0x489ee077994B6658eAfA855C308275EAd8097C4A;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant ETH_USD_PRICE_ORACLE =
        0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    uint256 public constant LEVERAGE = 20;
    uint256 public constant SLIPPAGE = 2; // 5%
    bytes32 public constant REF_CODE =
        0x0000000000000000000000000000000000000000000000000000000000000000;

    mapping(bytes32 => Position) public requestIds;
    mapping(address => EnumerableSetUpgradeable.Bytes32Set)
        private addrBytes32Set;

    address public vault;

    modifier onlyVault() {
        require(msg.sender == vault, "!vault");
        _;
    }

    uint256[50] private _gap;

    function initialize() public initializer {
        __Ownable_init();
        // vault = _vault;
    }


    function approvePositionRouterPlugin() external {
        IGmxRouter(GMX_ROUTER).approvePlugin(GMX_POSITION_ROUTER);
    }


    function openX20Long(address maker) public payable returns (bytes32) {
    }

    function openX20Short(address maker) public payable returns (bytes32) {
    }
    
    function closeAllPositions(address taker) external payable {}

    receive() external payable {}
}
