// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20, IProofOfHumanity, IHub, IGCT, IGroupMembershipDiscriminator} from "./interfaces.sol";

/** @title PoHGroupCurrencyManager
 *  - Is owner of GCT
 *  - GCT has owner-only minting
 *  - Organization in hub
 */
contract PoHGroupCurrencyManager is IGroupMembershipDiscriminator {
    event GovernorChanged(address newGovernor);
    event PoHChanged(address newPoH);
    event RedeemFeeChanged(uint8 newRedeemFeePerThousand);
    event ProfileUpdate(bytes20 indexed pohId, address indexed user);
    event Redeemed(
        address indexed redeemer,
        address indexed collateral,
        uint256 amount
    );

    // ========== STRUCTS ===========

    struct Profile {
        address user; // corresponding user of token for the profile
        uint256 minted; // counter of total minted group tokens; can be reset in case of having to replace token
    }

    // ========== STORAGE ===========

    // @dev Fee applied when redeeming collateral for group currency
    uint8 public redeemFeePerThousand;

    // @dev Contract able to execute governance functions
    address public governor;

    // @dev Proof of Humanity instance
    IProofOfHumanity public poh;

    // @dev GCT instance
    IGCT public gct;

    // @dev Hub instance
    IHub public hub;

    // @dev Storage gap
    uint256[50] internal __gap;

    // @dev Mapping of profiles corresponding to their pohId
    mapping(bytes20 => Profile) public profiles;

    // @dev Mapping of tokens to pohIds corresponding to the profiles
    // @dev Should only be non-null when token has never been set for a profile or after
    mapping(address => bytes20) public userToProfile;

    // ========== CONSTRUCTOR ==========

    function initialize(
        address _poh,
        address _gct,
        address _hub,
        uint8 _redeemFeePerThousand
    ) public {
        governor = msg.sender;
        poh = IProofOfHumanity(_poh);
        gct = IGCT(_gct);
        hub = IHub(_hub);

        redeemFeePerThousand = _redeemFeePerThousand;

        hub.organizationSignup();
    }

    // ========== GOVERNANCE ==========

    modifier onlyGovernor() {
        require(msg.sender == governor, "not governor");
        _;
    }

    function changeGovernor(address _newGovernor) external onlyGovernor {
        governor = _newGovernor;
        emit GovernorChanged(governor);
    }

    function changePoH(address _poh) external onlyGovernor {
        poh = IProofOfHumanity(_poh);
        emit PoHChanged(_poh);
    }

    function changeRedeemFeePerThousand(
        uint8 _redeemFeePerThousand
    ) external onlyGovernor {
        redeemFeePerThousand = _redeemFeePerThousand;
        emit RedeemFeeChanged(_redeemFeePerThousand);
    }

    function executeGovernorTx(
        address _destination,
        uint _amount,
        bytes calldata _data
    ) external onlyGovernor {
        (bool success, ) = _destination.call{value: _amount}(_data);
        require(success, "governor transaction failed");
    }

    // ========== FUNCTIONS ==========

    /** @dev Create profile corresponding to pohId of caller.
     *  @dev The user of the token will need to call `registerToken` in order to become member.
     *  @notice Must be called from wallet registered on PoH.
     *  @notice Alternatively see `directRegister()`.
     *  @param _token The token to be used for the profile.
     */
    function createProfile(address _token) external {
        address tokenUser = hub.tokenToUser(_token);
        require(tokenUser != address(0x0), "token not hub member");
        // user used must not correspond to another profile
        require(
            userToProfile[tokenUser] == bytes20(0x0),
            "user corresponds to a profile"
        );

        bytes20 pohId = poh.humanityOf(msg.sender);
        require(pohId != bytes20(0x0), "not registered on poh");

        Profile storage profile = profiles[pohId];
        // token should only be null when profile has not been yet created
        require(profile.user == address(0x0), "profile already created");

        // set token for profile so it can be confirmed when user token calls `registerToken`
        profile.user = tokenUser;

        emit ProfileUpdate(pohId, tokenUser);
    }

    /** @dev Register user after creating profile or after the minting was reset in order to replace user of token for profile.
     *  @notice Must be called from wallet having a token in the hub.
     *  @param _pohId The pohId corresponding to the profile the token should be added for.
     */
    function registerToken(bytes20 _pohId) external {
        address token = hub.userToToken(msg.sender);
        require(token != address(0x0), "user token not hub member");

        Profile storage profile = profiles[_pohId];
        require(
            profile.user == msg.sender,
            "profile user does not match to user token"
        );

        // check in case this function is called after resetMinted
        require(profile.minted == 0, "already started minting");

        userToProfile[msg.sender] = _pohId;

        gct.addMember(msg.sender);
    }

    /** @dev Create profile and register user for pohId in one function call in case PoH wallet and token wallet are the same.
     *  @dev The token user used must not correspond to another profile.
     *  @notice Must be called from wallet both registered on PoH and having a token in the hub.
     */
    function directRegister() external {
        require(
            hub.userToToken(msg.sender) != address(0x0),
            "token not hub member"
        );
        require(
            userToProfile[msg.sender] == bytes20(0x0),
            "token corresponds to a profile"
        );

        bytes20 pohId = poh.humanityOf(msg.sender);
        require(pohId != bytes20(0x0), "not registered on poh");

        Profile storage profile = profiles[pohId];
        // token should only be null when profile has not been yet created
        require(profile.user == address(0x0), "profile already created");

        profile.user = msg.sender;
        userToProfile[msg.sender] = pohId;

        gct.addMember(msg.sender);

        emit ProfileUpdate(pohId, msg.sender);
    }

    /** @dev Reset the number of minted tokens in order to replace token before calling `registerToken` again.
     *  @dev Must burn as many group tokens as were minted with the current profile token.
     *  @notice Must be called from PoH registered wallet corresponding since the ID recoverable.
     *  @param _newToken Address of the token to replace the current one.
     */
    function resetProfile(address _newToken) external {
        address tokenUser = hub.tokenToUser(_newToken);
        require(
            hub.tokenToUser(tokenUser) != address(0x0),
            "token not hub member"
        );
        // new token user used must not correspond to another profile
        require(
            userToProfile[tokenUser] == bytes20(0x0),
            "token corresponds to a profile"
        );

        bytes20 pohId = poh.humanityOf(msg.sender);
        require(pohId != bytes20(0x0), "sender not registered on poh");

        Profile storage profile = profiles[pohId];

        // user must burn same amount of group currency as totally minted
        require(
            gct.transferFrom(msg.sender, address(0x0), profile.minted),
            "must burn enough group tokens"
        );

        // remove corresponding profile for old token
        delete userToProfile[profile.user];

        // remove as group member
        gct.removeMember(profile.user);

        // update user to new one
        profile.user = tokenUser;

        // reset minted
        profile.minted = 0;

        emit ProfileUpdate(pohId, tokenUser);
    }

    /** @dev Deactivate profile corresponding to PoH ID of caller.
     */
    function deactivate() external {
        gct.removeMember(profiles[poh.humanityOf(msg.sender)].user);
    }

    /** @dev Deactivate profile not corresponding to PoH ID.
     *  @param _pohId PoH ID which, in case it is no longer claimed, to deactivate profile for.
     */
    function deactivateNonPoHRegistered(bytes20 _pohId) external {
        require(!poh.isClaimed(_pohId), "poh id is claimed");
        gct.removeMember(profiles[_pohId].user);
    }

    /** @dev Reactivate profile corresponding to PoH ID of caller after a previous deactivation.
     */
    function reactivate() external {
        // will revert in case of null pohId
        require(userToProfile[msg.sender] != bytes20(0x0), "not member");

        gct.addMember(msg.sender);
    }

    /** @dev Redeem collateral previously used to mint group tokens.
     *  @dev Must burn equal amount of group tokens (not considering the fee) as collateral asked.
     *  @param _redeemer Address to which to send redeemed collateral.
     *  @param _collateral Addresses of collateral to be redeemed.
     *  @param _amount Amounts of corresponding collateral to be redeemed.
     */
    function redeem(
        address _redeemer,
        address[] calldata _collateral,
        uint256[] calldata _amount
    ) external {
        uint256 nCollateral = _collateral.length;

        // calculate total of coins to redeem before applying the fee
        uint256 totalToRedeem;
        for (uint256 i; i < nCollateral; i++) {
            totalToRedeem += _amount[i];
        }

        uint256 redeemFee = (totalToRedeem * redeemFeePerThousand) / 1000;
        require(
            gct.transferFrom(
                msg.sender,
                address(0x0),
                totalToRedeem + redeemFee
            ),
            "did not burn enough group tokens"
        );

        // transfer the specified collateral to the redeemer
        for (uint256 i; i < nCollateral; i++) {
            address collateral = _collateral[i];
            uint256 amount = _amount[i];

            IERC20(collateral).transfer(_redeemer, amount);

            emit Redeemed(_redeemer, collateral, amount);
        }
    }

    // ========== DISCRIMINATOR ==========

    /** @dev Indicates whether user has profile and corresponds to a claimed PoH ID.
     *  @notice This is used for discriminator and does not check hub limits between gct and user.
     *  @param _user Address of user to check if it's member.
     *  @return Whether user is considered member of group.
     */
    function isMember(address _user) external view returns (bool) {
        return poh.isClaimed(userToProfile[_user]);
    }

    /** @dev Returns corresponding error messages when user does not have profile, or profile is not registered on poh.
     *  @notice This is used for discriminator and does not check hub limits between gct and user.
     *  @param _user Address of user to check if it's member.
     */
    function requireIsMember(address _user) external view {
        bytes20 pohId = userToProfile[_user];
        require(pohId != bytes20(0x0), "user does not correspond to a profile");
        require(poh.isClaimed(pohId), "profile not registered on PoH");
    }
}
