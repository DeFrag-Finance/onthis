//SPDX-License-Identifier: UNLICENSED

interface IWeth {
    function withdraw(uint256 amount) external;
    function balanceOf(address addr) external returns(uint256);

}