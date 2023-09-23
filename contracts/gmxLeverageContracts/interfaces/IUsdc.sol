//SPDX-License-Identifier: UNLICENSED

interface IUsdc {
    function balanceOf(address addr) external returns(uint256);
    function transfer(address recipient, uint256 amount)external returns(bool);
}