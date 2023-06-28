// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20, IProofOfHumanity, IHub, IGCT} from "./interfaces.sol";

// @title PoHGroupCurrencyManager
contract PoHGroupCurrencyManager {
    event ProfileCreated(bytes20 indexed pohId, address indexed token);
    event TokenRegistered(bytes20 indexed pohId, address indexed token);
    event ProfileReset(bytes20 indexed pohId, address indexed newToken);
    event Deactivated(bytes20 indexed pohId);
    event Reactivated(bytes20 indexed pohId);
    event Redeemed(
        address indexed redeemer,
        address indexed collateral,
        uint256 amount
    );

    // ========== STRUCTS ===========

    struct Profile {
        address token; // corresponding token for the profile
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
    mapping(address => bytes20) public tokenToProfile;

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
    }

    function changePoH(address _poh) external onlyGovernor {
        poh = IProofOfHumanity(_poh);
    }

    function changeRedeemFeePerThousand(
        uint8 _redeemFeePerThousand
    ) external onlyGovernor {
        redeemFeePerThousand = _redeemFeePerThousand;
    }

    // ========== FUNCTIONS ==========

    /** @dev Create profile corresponding to pohId of caller.
     *  @dev The user of the token will need to call `registerToken` in order to make the token a member.
     *  @notice Must be called from wallet registered on PoH.
     *  @notice Alternatively see `directRegister()`.
     *  @param _token The token to be used for the profile.
     */
    function createProfile(address _token) external {
        require(
            hub.tokenToUser(_token) != address(0x0),
            "token not hub member"
        );
        // token used must not correspond to another profile
        require(
            tokenToProfile[_token] == bytes20(0x0),
            "token corresponds to a profile"
        );

        bytes20 pohId = poh.humanityOf(msg.sender);
        require(pohId != bytes20(0x0), "not registered on poh");

        Profile storage profile = profiles[pohId];
        // token should only be null when profile has not been yet created
        require(profile.token == address(0x0), "profile already created");

        // set token for profile so it can be confirmed when user token calls `registerToken`
        profile.token = _token;

        emit ProfileCreated(pohId, _token);
    }

    /** @dev Register token after creating profile or after the minting was reset in order to replace token.
     *  @notice Must be called from wallet having a token in the hub.
     *  @param _pohId The pohId corresponding to the profile the token should be added for.
     */
    function registerToken(bytes20 _pohId) external {
        address token = hub.userToToken(msg.sender);
        require(token != address(0x0), "user token not hub member");

        Profile storage profile = profiles[_pohId];
        require(
            profile.token == token,
            "profile token does not match to user token"
        );

        // check in case this function is called after resetMinted
        require(profile.minted == 0, "already started minting");

        tokenToProfile[token] = _pohId;

        gct.addMemberToken(token);
    }

    /** @dev Create profile and register token for pohId in one function call in case PoH wallet and token wallet are the same.
     *  @dev The token used must not correspond to another profile.
     *  @notice Must be called from wallet both registered on PoH and having a token in the hub.
     */
    function directRegister() external {
        address token = hub.userToToken(msg.sender);
        require(token != address(0x0), "token not hub member");
        require(
            tokenToProfile[token] == bytes20(0x0),
            "token corresponds to a profile"
        );

        bytes20 pohId = poh.humanityOf(msg.sender);
        require(pohId != bytes20(0x0), "not registered on poh");

        Profile storage profile = profiles[pohId];
        // token should only be null when profile has not been yet created
        require(profile.token == address(0x0), "profile already created");

        profile.token = token;
        tokenToProfile[token] = pohId;

        gct.addMemberToken(token);

        emit ProfileCreated(pohId, token);
    }

    /** @dev Reset the number of minted tokens in order to replace token before calling `registerToken` again.
     *  @dev Must burn as many group tokens as were minted with the current profile token.
     *  @notice Must be called from PoH registered wallet corresponding since the ID recoverable.
     *  @param _newToken Address of the token to replace the current one.
     */
    function resetProfile(address _newToken) external {
        require(
            hub.tokenToUser(_newToken) != address(0x0),
            "token not hub member"
        );
        // new token used must not correspond to another profile
        require(
            tokenToProfile[_newToken] == bytes20(0x0),
            "token corresponds to a profile"
        );

        bytes20 pohId = poh.humanityOf(msg.sender);
        require(pohId != bytes20(0x0), "sender not registered on poh");

        Profile storage profile = profiles[pohId];

        // simple check to avoid user/ui mistake
        require(_newToken != profile.token, "must have new token");

        // user must burn same amount of group currency as totally minted
        require(
            gct.transferFrom(msg.sender, address(0x0), profile.minted),
            "must burn enough group tokens"
        );

        // remove corresponding profile for old token
        delete tokenToProfile[profile.token];

        // remove as group member
        gct.removeMemberToken(profile.token);

        // update token to new one
        profile.token = _newToken;

        // reset minted
        profile.minted = 0;

        emit ProfileReset(pohId, _newToken);
    }

    /** @dev Deactivate profile corresponding to PoH ID of caller.
     */
    function deactivate() external {
        gct.removeMemberToken(profiles[poh.humanityOf(msg.sender)].token);
    }

    /** @dev Deactivate profile not corresponding to PoH ID.
     *  @param _pohId PoH ID which, in case it is no longer claimed, to deactivate profile for.
     */
    function deactivateNonPoHRegistered(bytes20 _pohId) external {
        require(!poh.isClaimed(_pohId), "poh id is claimed");
        gct.removeMemberToken(profiles[_pohId].token);
    }

    /** @dev Reactivate profile corresponding to PoH ID of caller after a previous deactivation.
     */
    function reactivate() external {
        bytes20 pohId = poh.humanityOf(msg.sender);
        Profile storage profile = profiles[pohId];

        // will revert in case of null pohId
        require(tokenToProfile[profile.token] != bytes20(0x0), "not member");

        gct.addMemberToken(profile.token);
    }

    /** @dev Mint group tokens in amount specified backed 1-on-1 by specified collateral.
     *  @dev Must allow to send specified amount of collateral to this contract.
     *  @param _collateral Addresses of token to be used as collateral.
     *  @param _amount Amounts of corresponding tokens to mint.
     */
    function mint(
        address[] calldata _collateral,
        uint256[] calldata _amount
    ) external {
        address userToken = hub.userToToken(msg.sender);

        // check all collateral tokens for corresponding to claimed PoH ID
        uint256 nCollateral = _collateral.length;
        for (uint256 i; i < nCollateral; i++) {
            address collateral = _collateral[i];

            // if user uses collateral different from his token, check if that collateral corresponds to member token
            // in case poh id expired, no longer consider the token as member
            require(poh.isClaimed(tokenToProfile[collateral]), "not member");
            // trust check is done in GCT contract when minting
        }

        // mint tokens for this contract
        uint256 totalMinted = gct.mint(_collateral, _amount);

        // increment minted for profile
        profiles[tokenToProfile[userToken]].minted += totalMinted;

        // transfer total amount minted to caller
        gct.transfer(msg.sender, totalMinted);
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

    /** @dev Indicates whether token is group currency member and corresponds to a claimed PoH ID.
     *  @param _token Address of token to check if it's member.
     *  @return Whether token is considered member of group.
     */
    function isGroupMember(address _token) external view returns (bool) {
        return
            hub.limits(address(gct), _token) > 0 &&
            poh.isClaimed(tokenToProfile[_token]);
    }
}
