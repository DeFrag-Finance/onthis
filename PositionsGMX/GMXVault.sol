//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./L2GmxProxy.sol";

contract L2GmxVault is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    L2GmxProxy public gmxProxy;
    // user => address
    mapping(address => address) public userProxy;

    address public eligibleLongPositionOpener;
    address public eligibleShortPositionOpener;
    address public eligiblePositionCloser;
    address public deployedProxy;

    uint256[50] private _gap;

    function initialize() public initializer {
        __Ownable_init();
        deployedProxy = address(new L2GmxProxy());
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

    function setEligiblePositionCloser(
        address _eligibleLongPositionOpener
    ) external onlyOwner {
        eligiblePositionCloser = _eligibleLongPositionOpener;
    }

    function _createUsersGmxProxy(address owner) private returns (address) {
        address deployedAddress = Clones.clone(deployedProxy);
        L2GmxProxy(payable(deployedAddress)).initialize(address(this));
        L2GmxProxy(payable(deployedAddress)).approvePositionRouterPlugin();

        userProxy[owner] = address(deployedAddress);

        return address(deployedAddress);
    }

    function _openLeverageLong(address usersProxy, address maker) private {
        L2GmxProxy(payable(usersProxy)).openX20Long{value: msg.value}(maker);
    }

    function _openLeverageShort(address usersProxy, address maker) private {
        L2GmxProxy(payable(usersProxy)).openX20Short{value: msg.value}(maker);
    }

    function _closeAllLeveragePositions(
        address usersProxy,
        address maker
    ) private {
        return L2GmxProxy(payable(usersProxy)).closeAllPositions(maker);
    }

    function openX20Leverage(address maker, bool isLong) external payable {
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
            _openLeverageLong(usersGmxProxy, maker);
        } else {
            _openLeverageShort(usersGmxProxy, maker);
        }
    }

    function closeAllPositions(address maker) external {
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