// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IERC20 {
    function balanceOf(address account) external returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IProofOfHumanity {
    function isHuman(address _account) external view returns (bool);

    function isClaimed(bytes20 _pohId) external view returns (bool);

    function humanityOf(address _account) external view returns (bytes20);

    function boundTo(bytes20 _pohId) external view returns (address);
}

interface IHub {
    function userToToken(address) external returns (address);

    function tokenToUser(address) external returns (address);

    function trust(address, uint256) external;

    function limits(address, address) external view returns (uint256);
}

interface IGCT is IERC20 {
    function addMemberToken(address _member) external;

    function removeMemberToken(address _member) external;

    function mint(address[] calldata _collateral, uint256[] calldata _amount) external returns (uint256);
}
