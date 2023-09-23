//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./L2GmxProxy.sol";
import "./interfaces/IGmxReader.sol";
import "./interfaces/IL2GmxProxy.sol";

contract L2GmxVault is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    L2GmxProxy public gmxProxy;
    address public constant GMX_READER =
        0x22199a49A999c351eF7927602CFB187ec3cae489;
    address public constant GMX_VAULT =
        0x489ee077994B6658eAfA855C308275EAd8097C4A;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    // user => address
    mapping(address => address) public userProxy;

    address public eligibleLongPositionOpener;
    address public eligibleShortPositionOpener;
    address public eligiblePositionCloser;
    address public deployedProxy;

    uint256[50] private _gap;

    function initialize() public initializer {
        __Ownable_init();
    }

    function setDeployedProxy(address _deployedProxy) public onlyOwner {
        deployedProxy = _deployedProxy;
    }

    function setEligibleLongPositionOpener(
        address _eligibleLongPositionOpener
    ) external onlyOwner {
        eligibleLongPositionOpener = _eligibleLongPositionOpener;
    }

    function setEligibleShortPositionOpener(
        address _eligibleShortPositionOpener
    ) external onlyOwner {
        eligibleShortPositionOpener = _eligibleShortPositionOpener;
    }

    function _getColleralToken(
        bool isLong
    ) private pure returns (address[] memory) {
        if (isLong) {
            address[] memory path = new address[](1);
            path[0] = WETH;

            return path;
        } else {
            address[] memory path = new address[](1);
            path[0] = USDC;

            return path;
        }
    }

    function _getWethPath() private pure returns (address[] memory) {
        address[] memory path = new address[](1);
        path[0] = WETH;
        return path;
    }

    function _getPosition(bool isLong) private pure returns (bool[] memory) {
        bool[] memory path = new bool[](1);
        path[0] = isLong;
        return path;
    }

    struct Position {
        bool isProfitable;
        uint256 usdRoi;
    }

    function getPositionEthDataRoi(
        address maker,
        bool isLong
    ) public view returns (Position memory) {
        address usersGmxProxy = userProxy[maker];

        uint256[] memory data = IGmxReader(GMX_READER).getPositions(
            GMX_VAULT,
            usersGmxProxy,
            _getColleralToken(isLong),
            _getWethPath(),
            _getPosition(isLong)
        );

        bool isProfitable = data[7] == 1 ? true : false;

        return Position(isProfitable, data[8]);
    }

    function setEligiblePositionCloser(
        address _eligibleLongPositionOpener
    ) external onlyOwner {
        eligiblePositionCloser = _eligibleLongPositionOpener;
    }

    function _createUsersGmxProxy(address owner) private returns (address) {
        address deployedAddress = address(new L2GmxProxy());

        L2GmxProxy(payable(deployedAddress)).initialize(address(this)); //initialize address(this);
        L2GmxProxy(payable(deployedAddress)).approvePositionRouterPlugin();

        userProxy[owner] = address(deployedAddress);

        return address(deployedAddress);
    }

    function _openLeverageLong(
        address usersProxy,
        address maker
    ) private returns (bytes32) {
    
        return
            L2GmxProxy(payable(usersProxy)).openX20Long{value: msg.value}(
                maker
            );
    }

    function _openLeverageShort(
        address usersProxy,
        address maker
    ) private returns (bytes32) {
        return
            L2GmxProxy(payable(usersProxy)).openX20Short{value: msg.value}(
                maker
            );
    }

    function _closeAllLeveragePositions(
        address usersProxy,
        address maker
    ) private {
        return
            L2GmxProxy(payable(usersProxy)).closeAllPositions{value: msg.value}(
                maker
            );
    }

    function openX20Leverage(
        address maker,
        bool isLong
    ) external payable returns (bytes32) {
        address usersGmxProxy = userProxy[maker];

        // if (isLong) {
        //     require(
        //         msg.sender == eligibleLongPositionOpener,
        //         "!eligibleLongPositionOpener"
        //     );
        // } else {
        //     require(
        //         msg.sender == eligibleShortPositionOpener,
        //         "!eligibleShortPositionOpener"
        //     );
        // }

        if (usersGmxProxy == address(0)) {
            usersGmxProxy = _createUsersGmxProxy(maker);
        }

        if (isLong) {
            return _openLeverageLong(usersGmxProxy, maker);
        } else {
            return _openLeverageShort(usersGmxProxy, maker);
        }
    }

    function closeAllPositions(address maker) external payable {
        address usersGmxProxy = userProxy[maker];
        // require(
        //     msg.sender == eligiblePositionCloser,
        //     "!eligibleShortPositionOpener"
        // );
        require(usersGmxProxy != address(0), "dont have own proxy");

        _closeAllLeveragePositions(usersGmxProxy, maker);
    }

    receive() external payable {}
}
