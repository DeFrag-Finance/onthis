pragma solidity ^0.8.9;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./L1GmxBase.sol";
import "./interfaces/CrosschainPortal.sol";
import "hardhat/console.sol";
contract L1CloseAllGmxPositions is L1GmxBase {
    receive() external payable {        
        bytes memory closeAllPositionsData = abi.encodeWithSelector(
            bytes4(keccak256("closeAllPositions(address)")),
            msg.sender
        );
     
        uint256 requiredValue = MAX_SUBMISSION_COST +
            GAS_LIMIT_FOR_CALL *
            MAX_FEE_PER_GAS;
        CrosschainPortal(CROSS_CHAIN_PORTAL).createRetryableTicket{
            value: msg.value
        }(
            ARB_RECEIVER,  
            msg.value - requiredValue,
            MAX_SUBMISSION_COST,
            msg.sender,
            msg.sender,
            GAS_LIMIT_FOR_CALL,
            MAX_FEE_PER_GAS,
            closeAllPositionsData
        );
    }
}
