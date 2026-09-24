// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "solady/auth/Ownable.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

/**
 * @title  WhitelistClaim
 * @notice The on-chain register of MintABear's whitelist campaign: 1,000 allocations, first come
 *         first served, each claimed by a wagering holder with a voucher from MINT's eligibility
 *         signer. The whitelist stage's allowlist in OpenSea Studio is exported from
 *         `claimants`, so anyone can recompute it from the chain and check it.
 * @dev    A voucher is the EIP-712 message
 *         `Claim(address wallet,uint8 allocationIndex,bytes32 account,uint256 deadline)`, where
 *         `account` is a hash of the getminted.io account id, so the chain carries no personal
 *         data. The wallet sends its own claim and pays the gas.
 *
 *         `allocationIndex` is the account's allocation number — 1 for the allocation $50 of
 *         wagering unlocks, 2 for the one $100 unlocks — and must equal the account's claims so
 *         far plus one. A voucher is therefore bound to the account's tier whichever wallet the
 *         holder selects: a second voucher for allocation 1, for another wallet, is refused once
 *         the first is claimed. It also needs no nonce: once used, its index is behind the
 *         account's count and it can never succeed again, and ECDSA malleability is harmless for
 *         the same reason.
 *
 *         The owner (MINT's admin) sets the signer and the campaign window and nothing else, and
 *         can hand ownership over but never renounce it. No function removes or reassigns a
 *         claim, and every claim was made by its wallet with a voucher from the signer — so the
 *         signer, and the owner through `setSigner`, decide who may claim.
 *
 *         Slither reports `locked-ether` because Solady's ownership functions are `payable`
 *         (a gas saving). Anyone can call `requestOwnershipHandover` and
 *         `cancelOwnershipHandover`, so anyone could lock their own ETH by attaching value to
 *         them; nothing here withdraws it, and nothing else accepts ETH.
 */
contract WhitelistClaim is Ownable, EIP712 {
    /// @notice Whitelist allocations in the campaign. Each is the right to mint one bear in the
    ///         whitelist stage.
    uint16 public constant TOTAL_SPOTS = 1000;

    /// @notice Allocations one wallet can hold.
    uint8 public constant MAX_PER_WALLET = 2;

    /// @notice Allocations one getminted.io account can claim, over however many wallets.
    uint8 public constant MAX_PER_ACCOUNT = 2;

    /// @notice EIP-712 type hash of the voucher.
    bytes32 public constant CLAIM_TYPEHASH =
        keccak256("Claim(address wallet,uint8 allocationIndex,bytes32 account,uint256 deadline)");

    /// @notice A voucher, as signed by the eligibility signer.
    /// @param wallet          The NFT wallet the allocation is claimed for; it sends the claim.
    /// @param allocationIndex The account's allocation number: 1 ($50 wagered), 2 ($100).
    /// @param account         Hash of the getminted.io account id.
    /// @param deadline        Last timestamp at which the voucher is accepted.
    struct Claim {
        address wallet;
        uint8 allocationIndex;
        bytes32 account;
        uint256 deadline;
    }

    /// @notice One row of the export: a wallet and the allocations it holds.
    struct Claimant {
        address wallet;
        uint8 allocations;
    }

    /// @notice Key that signs vouchers.
    /// @dev    `signer`, `openAt`, `closeAt` and the spot counter share one storage slot
    ///         (20 + 5 + 5 + 2 bytes), so `claim` reads every global guard with a single SLOAD.
    address public signer;

    /// @notice First timestamp at which claims are accepted.
    uint40 public openAt;

    /// @notice Last timestamp at which claims are accepted.
    uint40 public closeAt;

    /// @dev Allocations claimed so far, and the number the next claim takes minus one.
    uint16 private _spotsClaimed;

    /// @notice Allocations each wallet has claimed.
    mapping(address => uint8) public claimsOf;

    /// @notice Allocations each account (by hash) has claimed.
    mapping(bytes32 => uint8) public accountClaims;

    /// @dev Every wallet that holds an allocation, once each, in order of its first claim.
    address[] private _claimants;

    /// @notice An allocation was claimed. `spotNumber` counts from 1 across the campaign.
    event WhitelistClaimed(address indexed wallet, uint8 allocationIndex, bytes32 indexed account, uint256 spotNumber);

    /// @notice The eligibility signer was set.
    event SignerSet(address indexed signer);

    /// @notice The campaign window was set.
    event WindowSet(uint40 openAt, uint40 closeAt);

    /// @notice The claim was not sent by the voucher's wallet.
    error NotClaimant();

    /// @notice The voucher was not signed by the eligibility signer.
    error BadSigner();

    /// @notice The voucher's deadline has passed.
    error Expired();

    /// @notice The campaign window is not open.
    error CampaignClosed();

    /// @notice All `TOTAL_SPOTS` allocations are claimed.
    error SoldOut();

    /// @notice The wallet already holds `MAX_PER_WALLET` allocations.
    error WalletLimit();

    /// @notice The voucher's allocation is not the account's next one.
    error WrongAllocation();

    /// @notice The account has already claimed `MAX_PER_ACCOUNT` allocations.
    error AccountLimit();

    /// @notice The signer cannot be the zero address.
    error ZeroSigner();

    /// @notice A window must open before it closes.
    error InvalidWindow();

    /// @notice Ownership can be handed over, never renounced.
    error RenounceDisabled();

    /**
     * @param owner_   MINT's admin: sets the signer and the window. Not the zero address.
     * @param signer_  The eligibility signer.
     * @param openAt_  First timestamp at which claims are accepted.
     * @param closeAt_ Last timestamp at which claims are accepted; at least 48 hours before the
     *                 whitelist stage opens.
     */
    constructor(address owner_, address signer_, uint40 openAt_, uint40 closeAt_) {
        // Solady's `_initializeOwner` accepts the zero address; an ownerless registry could never
        // rotate its signer or move its window, so it is refused as `transferOwnership` refuses it.
        if (owner_ == address(0)) revert NewOwnerIsZeroAddress();
        _initializeOwner(owner_);
        _setSigner(signer_);
        _setWindow(openAt_, closeAt_);
    }

    /**
     * @notice Claims the account's next allocation, for the voucher's wallet, with a voucher from
     *         the eligibility signer.
     * @dev    Must be sent by `voucher.wallet`. Reverts, in this order, with `NotClaimant`,
     *         `BadSigner`, `Expired`, `CampaignClosed`, `SoldOut`, `WalletLimit`,
     *         `AccountLimit` or `WrongAllocation`. A claim either takes a spot whole or fails.
     * @param  voucher   The signed voucher.
     * @param  signature The signer's signature over the voucher's EIP-712 digest (65 bytes, or
     *                   64 in EIP-2098 form).
     */
    function claim(Claim calldata voucher, bytes calldata signature) external {
        if (msg.sender != voucher.wallet) revert NotClaimant();

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(CLAIM_TYPEHASH, voucher.wallet, voucher.allocationIndex, voucher.account, voucher.deadline)
            )
        );
        // `tryRecoverCalldata` returns the zero address for an invalid signature, and `signer`
        // is never zero, so an invalid signature can never match.
        if (ECDSA.tryRecoverCalldata(digest, signature) != signer) revert BadSigner();

        if (block.timestamp > voucher.deadline) revert Expired();
        if (block.timestamp < openAt || block.timestamp > closeAt) revert CampaignClosed();

        uint16 claimed = _spotsClaimed;
        if (claimed >= TOTAL_SPOTS) revert SoldOut();

        uint8 walletClaims = claimsOf[voucher.wallet];
        if (walletClaims >= MAX_PER_WALLET) revert WalletLimit();

        uint8 accountCount = accountClaims[voucher.account];
        if (accountCount >= MAX_PER_ACCOUNT) revert AccountLimit();
        if (voucher.allocationIndex != accountCount + 1) revert WrongAllocation();

        if (walletClaims == 0) _claimants.push(voucher.wallet);
        claimsOf[voucher.wallet] = walletClaims + 1;
        accountClaims[voucher.account] = accountCount + 1;
        _spotsClaimed = ++claimed;

        emit WhitelistClaimed(voucher.wallet, voucher.allocationIndex, voucher.account, claimed);
    }

    /// @notice Allocations still unclaimed — the live counter "spots left — X / 1,000".
    function spotsLeft() external view returns (uint256) {
        return TOTAL_SPOTS - _spotsClaimed;
    }

    /**
     * @notice A page of the claimant list, for the export to the Studio allowlist: each wallet
     *         once, in order of its first claim, with the allocations it holds.
     * @dev    A page past the end is short or empty; the export reads pages until one comes back
     *         shorter than `limit`.
     * @param  offset Index of the first row.
     * @param  limit  Most rows to return.
     */
    function claimants(uint256 offset, uint256 limit) external view returns (Claimant[] memory rows) {
        uint256 total = _claimants.length;
        uint256 end = offset >= total ? offset : (limit > total - offset ? total : offset + limit);
        rows = new Claimant[](end - offset);
        for (uint256 i; i < rows.length; ++i) {
            address wallet = _claimants[offset + i];
            rows[i] = Claimant({wallet: wallet, allocations: claimsOf[wallet]});
        }
    }

    /// @notice Sets the eligibility signer. Vouchers the previous signer issued stop working.
    /// @param  signer_ The new signer; not the zero address.
    function setSigner(address signer_) external onlyOwner {
        _setSigner(signer_);
    }

    /// @notice Sets the campaign window; claims are accepted from `openAt_` to `closeAt_`
    ///         inclusive. Claims already made stay.
    /// @param  openAt_  First timestamp at which claims are accepted.
    /// @param  closeAt_ Last timestamp at which claims are accepted; after `openAt_`.
    function setWindow(uint40 openAt_, uint40 closeAt_) external onlyOwner {
        _setWindow(openAt_, closeAt_);
    }

    /// @notice Refused for every caller, the owner included, so the signer can always be rotated
    ///         and the window moved.
    function renounceOwnership() public payable override {
        revert RenounceDisabled();
    }

    function _setSigner(address signer_) private {
        if (signer_ == address(0)) revert ZeroSigner();
        signer = signer_;
        emit SignerSet(signer_);
    }

    function _setWindow(uint40 openAt_, uint40 closeAt_) private {
        if (openAt_ >= closeAt_) revert InvalidWindow();
        openAt = openAt_;
        closeAt = closeAt_;
        emit WindowSet(openAt_, closeAt_);
    }

    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "WhitelistClaim";
        version = "1";
    }
}
