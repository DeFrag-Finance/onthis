//SPDX-License-Identifier: UNLICENSED

interface IChainlinkPriceOracle {
    function latestAnswer() external returns(uint256);

    function decimals() external returns(uint256);
}
