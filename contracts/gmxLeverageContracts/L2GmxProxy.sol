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
    address public constant FEE_RECEIVER =
        0xCe03b880634EbD9bD0F6974CcF430EDED3A8363F;

    uint256 public constant LEVERAGE = 10;
    uint256 public constant SLIPPAGE = 2; // 5%
    uint256 public constant PROJECT_FEE_PERCENTRAGE = 10;

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

    function initialize(address _vault) public initializer {
        __Ownable_init();
        vault = _vault;
    }

    function gmxPositionCallback(
        bytes32 positionKey,
        bool isExecuted,
        bool isIncrease
    ) external {
        require(GMX_POSITION_ROUTER == msg.sender, "!GMX_POSITION_ROUTER");
        Position storage position = requestIds[positionKey];

        // open position request was succesfully submitted
        if (isExecuted && isIncrease) {
            position.isConfirmed = true;
        }
        // cancel short tx by oracle
        // close position request was succesfully submitted ||  open position request was NOT succesfully submitted
        if ((isExecuted && !isIncrease) || (!isExecuted && isIncrease)) {
            _refund(position.maker, position.isLong, isExecuted);

            addrBytes32Set[position.maker].remove(positionKey);

            delete requestIds[positionKey];
        }

        // close position request was NOT succesfully submitted it means that is was liqudated
        if (!isExecuted && !isIncrease) {
      
            addrBytes32Set[position.maker].remove(positionKey);
            delete requestIds[positionKey];
        }
    }

    function _refund(address to, bool isLong, bool isCancelled) private {
        if (isLong || !isCancelled) {

            payable(to).transfer(address(this).balance);
        } else {
        
            IUsdc(USDC).transfer(to, IUsdc(USDC).balanceOf(address(this)));
        }
    }

    function approvePositionRouterPlugin() external {
        IGmxRouter(GMX_ROUTER).approvePlugin(GMX_POSITION_ROUTER);
    }

    function _getPath(
        bool isLong,
        bool isIncrease
    ) private pure returns (address[] memory) {
        if ((isLong && isIncrease) || (isLong && !isIncrease)) {
            address[] memory path = new address[](1);
            path[0] = WETH;

            return path;
        } else if (!isLong && isIncrease) {
            address[] memory path = new address[](2);
            path[0] = WETH;
            path[1] = USDC;

            return path;
        } else {
            address[] memory path = new address[](1);
            path[0] = USDC;

            return path;
        }
    }

    function _getGmxExecutionFee() private returns (uint256) {
        return IGmxPositionRouter(GMX_POSITION_ROUTER).minExecutionFee();
    }

    function _getEthUsdPrice() private returns (uint256) {
        return IChainlinkPriceOracle(ETH_USD_PRICE_ORACLE).latestAnswer();
    }

    function _getEthUsdDecimals() private returns (uint256) {
        return IChainlinkPriceOracle(ETH_USD_PRICE_ORACLE).decimals();
    }

    function _calculateSizeDelta(
        uint256 priceAfterProjectFees
    ) private returns (uint256) {
        uint256 ethUsdPrice = _getEthUsdPrice();
        uint256 ethUsdDecimals = _getEthUsdDecimals();
        uint256 valueInUsdt = (priceAfterProjectFees * ethUsdPrice) /
            (10 ** ethUsdDecimals); // 8

        uint256 sizeDelta = valueInUsdt * LEVERAGE * (10 ** 12);

        return sizeDelta;
    }

    function _calculateAcceptablePrice(bool isLong) private returns (uint256) {
        uint256 ethUsdPrice = _getEthUsdPrice();
        uint256 ethUsdDecimals = _getEthUsdDecimals();
        uint256 requiredPrecission = 10 ** (30 - ethUsdDecimals);
        ethUsdPrice *= requiredPrecission;
        return
            isLong
                ? (ethUsdPrice + (ethUsdPrice * SLIPPAGE) / 100)
                : (ethUsdPrice - (ethUsdPrice * SLIPPAGE) / 100);
    }

    function _sendProjectFees(uint256 amount) private {
        payable(FEE_RECEIVER).transfer(amount);
    }

    function _createX20LeveragePosition(
        address maker,
        bool isLong
    ) private returns (bytes32 requestKey) {
        uint256 fee = _getGmxExecutionFee();

        uint256 projectFee = (msg.value / PROJECT_FEE_PERCENTRAGE);
        uint256 priceAfterProjectFees = msg.value - projectFee;

        uint256 sizeDelta = _calculateSizeDelta(priceAfterProjectFees);

        uint256 acceptablePrice = _calculateAcceptablePrice(isLong);

        _sendProjectFees(projectFee);

        requestKey = IGmxPositionRouter(GMX_POSITION_ROUTER)
            .createIncreasePositionETH{value: priceAfterProjectFees}(
            _getPath(isLong, true),
            WETH,
            0,
            sizeDelta,
            isLong,
            acceptablePrice,
            fee,
            REF_CODE,
            address(this)
        );

        requestIds[requestKey] = (
            Position(maker, false, true, isLong, sizeDelta)
        );
        addrBytes32Set[maker].add(requestKey);

        emit RequestCreated(requestKey);

        return requestKey;
    }

    function _closePosition(address taker, bool isLong, bytes32 reqId) private {
        uint256 fee = _getGmxExecutionFee();
        uint256 acceptablePrice;
        bool isLongCopy = isLong;

        if (isLong) {
            acceptablePrice = IGMXVault(GMX_VAULT).getMinPrice(WETH);
        } else {
            acceptablePrice = IGMXVault(GMX_VAULT).getMaxPrice(WETH);
        }

        Position memory position = requestIds[reqId];


        bytes32 requestKey = IGmxPositionRouter(GMX_POSITION_ROUTER)
            .createDecreasePosition{value: fee}(
            _getPath(isLongCopy, false),
            WETH,
            0,
            position.sizeDelta,
            isLongCopy,
            address(this),
            acceptablePrice,
            0,
            fee,
            isLongCopy,
            address(this)
        );

        requestIds[requestKey] = (Position(taker, false, false, isLong, 0));

        addrBytes32Set[taker].add(requestKey);

        emit CancelRequestCreated(requestKey);
    }

    function openX20Long(
        address maker
    ) public payable onlyVault returns (bytes32) {
        return _createX20LeveragePosition(maker, true);
    }

    function openX20Short(
        address maker
    ) public payable onlyVault returns (bytes32) {
        return _createX20LeveragePosition(maker, false);
    }

    function closeAllPositions(address taker) external payable onlyVault {
        bytes32[] memory takerRequests = addrBytes32Set[taker].values();
        uint256 fee = _getGmxExecutionFee();

        if (takerRequests.length * fee <= msg.value) {
            for (uint256 i = 0; i < takerRequests.length; i++) {
                Position memory takerPositions = requestIds[takerRequests[i]];

                if (takerPositions.isConfirmed) {
                    _closePosition(
                        taker,
                        takerPositions.isLong,
                        takerRequests[i]
                    );
                }
            }
            payable(taker).transfer(msg.value - takerRequests.length * fee);
        } else {
            payable(taker).transfer(msg.value);
        }
    }

    receive() external payable {}
}
