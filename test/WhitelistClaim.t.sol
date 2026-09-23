// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {MerkleTreeLib} from "solady/utils/MerkleTreeLib.sol";
import {SeaDrop} from "seadrop/SeaDrop.sol";
import {AllowListData, MintParams} from "seadrop/lib/SeaDropStructs.sol";
import {SeaDropErrorsAndEvents} from "seadrop/lib/SeaDropErrorsAndEvents.sol";

import {MintABear} from "../src/MintABear.sol";
import {WhitelistClaim} from "../src/WhitelistClaim.sol";

/// @dev Shared fixture: a registry owned by MINT's admin, a campaign window that is open, and an
///      eligibility signer whose key signs vouchers over a digest computed here independently of
///      the contract, so a wrong type hash or domain in the contract fails the suite.
abstract contract WhitelistClaimBase is Test {
    WhitelistClaim internal wl;

    address internal admin = makeAddr("mintAdmin");
    address internal signer;
    uint256 internal signerKey;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    bytes32 internal constant ACCOUNT_A = keccak256("getminted:account-a");
    bytes32 internal constant ACCOUNT_B = keccak256("getminted:account-b");

    uint40 internal constant OPEN_AT = 1_791_244_800; // 2026-10-06 00:00 UTC
    uint40 internal constant CLOSE_AT = 1_792_972_799; // 2026-10-25 23:59:59 UTC
    uint256 internal constant VOUCHER_TTL = 10 minutes;

    bytes32 internal constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant CLAIM_TYPEHASH =
        keccak256("Claim(address wallet,uint8 allocationIndex,bytes32 account,uint256 deadline)");

    event WhitelistClaimed(address indexed wallet, uint8 allocationIndex, bytes32 indexed account, uint256 spotNumber);
    event SignerSet(address indexed signer);
    event WindowSet(uint40 openAt, uint40 closeAt);

    function setUp() public virtual {
        (signer, signerKey) = makeAddrAndKey("eligibilitySigner");
        wl = new WhitelistClaim(admin, signer, OPEN_AT, CLOSE_AT);
        vm.warp(OPEN_AT);
    }

    function _digest(WhitelistClaim.Claim memory v) internal view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256("WhitelistClaim"), keccak256("1"), block.chainid, address(wl))
        );
        bytes32 structHash = keccak256(abi.encode(CLAIM_TYPEHASH, v.wallet, v.allocationIndex, v.account, v.deadline));
        return keccak256(abi.encodePacked("\x19\x01", domain, structHash));
    }

    function _voucher(address wallet, uint8 index, bytes32 account)
        internal
        view
        returns (WhitelistClaim.Claim memory)
    {
        return WhitelistClaim.Claim({
            wallet: wallet, allocationIndex: index, account: account, deadline: block.timestamp + VOUCHER_TTL
        });
    }

    function _sign(uint256 key, WhitelistClaim.Claim memory v) internal view returns (bytes memory) {
        (uint8 sv, bytes32 r, bytes32 s) = vm.sign(key, _digest(v));
        return abi.encodePacked(r, s, sv);
    }

    /// @dev `wallet` claims allocation `index` for `account` with a voucher from the signer.
    function _claim(address wallet, uint8 index, bytes32 account) internal {
        WhitelistClaim.Claim memory v = _voucher(wallet, index, account);
        bytes memory sig = _sign(signerKey, v);
        vm.prank(wallet);
        wl.claim(v, sig);
    }

    /// @dev Expects `wallet`'s claim of allocation `index` for `account` to revert with `err`.
    function _expectClaimRevert(address wallet, uint8 index, bytes32 account, bytes4 err) internal {
        WhitelistClaim.Claim memory v = _voucher(wallet, index, account);
        bytes memory sig = _sign(signerKey, v);
        vm.prank(wallet);
        vm.expectRevert(err);
        wl.claim(v, sig);
    }
}

/// @dev WL-3. The registry: voucher, `claim`, its reverts, the reads and the owner functions.
contract WhitelistClaimRegistryTest is WhitelistClaimBase {
    function test_claim_validVoucher_claimsASpot_andRefusesAnotherSender() public {
        /* Scenario: WL-3 — A valid voucher claims a spot
           Given a voucher signed by the signer for wallet W, allocation 1, within its deadline
             and the campaign window
           When W calls claim
           Then spotsLeft falls by one, claimsOf(W) reads 1 and WhitelistClaimed is emitted
           And the same call from another wallet reverts with NotClaimant */
        WhitelistClaim.Claim memory v = _voucher(alice, 1, ACCOUNT_A);
        bytes memory sig = _sign(signerKey, v);

        vm.prank(bob);
        vm.expectRevert(WhitelistClaim.NotClaimant.selector);
        wl.claim(v, sig);

        vm.expectEmit(true, true, true, true, address(wl));
        emit WhitelistClaimed(alice, 1, ACCOUNT_A, 1);
        vm.prank(alice);
        wl.claim(v, sig);

        assertEq(wl.spotsLeft(), 999);
        assertEq(wl.claimsOf(alice), 1);
        assertEq(wl.accountClaims(ACCOUNT_A), 1);

        vm.prank(bob);
        vm.expectRevert(WhitelistClaim.NotClaimant.selector);
        wl.claim(v, sig);
    }

    function test_claim_spotNumberCountsAcrossTheCampaign() public {
        /* Scenario:
           Given two claims already made
           When a third wallet claims
           Then WhitelistClaimed carries spot number 3 and spotsLeft reads 997 */
        _claim(alice, 1, ACCOUNT_A);
        _claim(bob, 1, ACCOUNT_B);

        WhitelistClaim.Claim memory v = _voucher(carol, 1, keccak256("getminted:account-c"));
        bytes memory sig = _sign(signerKey, v);
        vm.expectEmit(true, true, true, true, address(wl));
        emit WhitelistClaimed(carol, 1, v.account, 3);
        vm.prank(carol);
        wl.claim(v, sig);
        assertEq(wl.spotsLeft(), 997);
    }

    function test_claim_compactSignature_isAccepted() public {
        /* Scenario:
           Given a voucher signed in EIP-2098 64-byte form
           When its wallet claims
           Then the claim succeeds */
        WhitelistClaim.Claim memory v = _voucher(alice, 1, ACCOUNT_A);
        (bytes32 r, bytes32 vs) = vm.signCompact(signerKey, _digest(v));
        vm.prank(alice);
        wl.claim(v, abi.encodePacked(r, vs));
        assertEq(wl.claimsOf(alice), 1);
    }

    function test_claim_revertsWithBadSigner_whenSignedByAnotherKey() public {
        /* Scenario:
           Given a voucher signed by a key other than the signer
           When its wallet claims
           Then it reverts with BadSigner */
        (, uint256 otherKey) = makeAddrAndKey("impostor");
        WhitelistClaim.Claim memory v = _voucher(alice, 1, ACCOUNT_A);
        bytes memory sig = _sign(otherKey, v);
        vm.prank(alice);
        vm.expectRevert(WhitelistClaim.BadSigner.selector);
        wl.claim(v, sig);
    }

    function test_claim_revertsWithBadSigner_whenAFieldIsAltered() public {
        /* Scenario:
           Given a voucher signed by the signer
           When its wallet claims with the account, allocation or deadline altered
           Then each attempt reverts with BadSigner */
        WhitelistClaim.Claim memory v = _voucher(alice, 1, ACCOUNT_A);
        bytes memory sig = _sign(signerKey, v);

        WhitelistClaim.Claim memory altered = _voucher(alice, 1, ACCOUNT_B);
        vm.prank(alice);
        vm.expectRevert(WhitelistClaim.BadSigner.selector);
        wl.claim(altered, sig);

        altered = _voucher(alice, 2, ACCOUNT_A);
        vm.prank(alice);
        vm.expectRevert(WhitelistClaim.BadSigner.selector);
        wl.claim(altered, sig);

        altered = _voucher(alice, 1, ACCOUNT_A);
        altered.deadline = v.deadline + 1 days;
        vm.prank(alice);
        vm.expectRevert(WhitelistClaim.BadSigner.selector);
        wl.claim(altered, sig);
    }

    function test_claim_revertsWithBadSigner_whenTheSignatureIsMalformed() public {
        /* Scenario:
           Given a signature that is neither 64 nor 65 bytes
           When a wallet claims with it
           Then it reverts with BadSigner, never matching a zero signer */
        WhitelistClaim.Claim memory v = _voucher(alice, 1, ACCOUNT_A);
        vm.prank(alice);
        vm.expectRevert(WhitelistClaim.BadSigner.selector);
        wl.claim(v, hex"deadbeef");
    }

    function test_claim_revertsWithBadSigner_forAVoucherFromAnotherDeployment() public {
        /* Scenario:
           Given a voucher signed for a second registry at another address
           When its wallet presents it to this registry
           Then it reverts with BadSigner: the domain binds the voucher to one contract */
        WhitelistClaim other = new WhitelistClaim(admin, signer, OPEN_AT, CLOSE_AT);
        WhitelistClaim.Claim memory v = _voucher(alice, 1, ACCOUNT_A);
        WhitelistClaim saved = wl;
        wl = other;
        bytes memory sig = _sign(signerKey, v);
        wl = saved;

        vm.prank(alice);
        vm.expectRevert(WhitelistClaim.BadSigner.selector);
        wl.claim(v, sig);
    }

    function test_claim_revertsWithExpired_afterTheDeadline() public {
        /* Scenario:
           Given a voucher whose deadline has passed, inside the campaign window
           When its wallet claims
           Then it reverts with Expired */
        WhitelistClaim.Claim memory v = _voucher(alice, 1, ACCOUNT_A);
        bytes memory sig = _sign(signerKey, v);
        vm.warp(v.deadline + 1);
        vm.prank(alice);
        vm.expectRevert(WhitelistClaim.Expired.selector);
        wl.claim(v, sig);
    }

    function test_claim_atTheDeadline_succeeds() public {
        /* Scenario:
           Given a voucher at exactly its deadline
           When its wallet claims
           Then the claim succeeds */
        WhitelistClaim.Claim memory v = _voucher(alice, 1, ACCOUNT_A);
        bytes memory sig = _sign(signerKey, v);
        vm.warp(v.deadline);
        vm.prank(alice);
        wl.claim(v, sig);
        assertEq(wl.claimsOf(alice), 1);
    }

    function test_claim_revertsWithCampaignClosed_outsideTheWindow() public {
        /* Scenario:
           Given a valid voucher
           When the claim arrives before openAt or after closeAt
           Then it reverts with CampaignClosed */
        vm.warp(OPEN_AT - 1);
        _expectClaimRevert(alice, 1, ACCOUNT_A, WhitelistClaim.CampaignClosed.selector);
        vm.warp(uint256(CLOSE_AT) + 1);
        _expectClaimRevert(alice, 1, ACCOUNT_A, WhitelistClaim.CampaignClosed.selector);
    }

    function test_claim_revertsWithSoldOut_afterTheLastSpot() public {
        /* Scenario:
           Given all 1,000 allocations claimed
           When another wallet claims with a valid voucher
           Then it reverts with SoldOut and nothing changes */
        for (uint256 i; i < 500; ++i) {
            address wallet = makeAddr(string(abi.encode("claimant", i)));
            bytes32 account = keccak256(abi.encode("account", i));
            _claim(wallet, 1, account);
            _claim(wallet, 2, account);
        }
        assertEq(wl.spotsLeft(), 0);

        _expectClaimRevert(alice, 1, ACCOUNT_A, WhitelistClaim.SoldOut.selector);
        assertEq(wl.claimsOf(alice), 0);
        assertEq(wl.accountClaims(ACCOUNT_A), 0);
        assertEq(wl.claimants(0, 1000).length, 500);
    }

    function test_claim_revertsWithWalletLimit_onAThirdAllocation() public {
        /* Scenario:
           Given a wallet holding two allocations
           When it claims with a voucher for allocation 3
           Then it reverts with WalletLimit */
        _claim(alice, 1, ACCOUNT_A);
        _claim(alice, 2, ACCOUNT_A);
        _expectClaimRevert(alice, 3, ACCOUNT_B, WhitelistClaim.WalletLimit.selector);
    }

    function test_claim_revertsWithWrongAllocation_outOfOrder() public {
        /* Scenario:
           Given a wallet with no allocation
           When it claims with a voucher for allocation 2 or allocation 0
           Then it reverts with WrongAllocation */
        _expectClaimRevert(alice, 2, ACCOUNT_A, WhitelistClaim.WrongAllocation.selector);
        _expectClaimRevert(alice, 0, ACCOUNT_A, WhitelistClaim.WrongAllocation.selector);
    }

    function test_claim_revertsWithWrongAllocation_onAReplayedVoucher() public {
        /* Scenario:
           Given a wallet that has claimed allocation 1 with a voucher
           When it presents the same voucher again
           Then it reverts with WrongAllocation: a voucher is spent once used */
        WhitelistClaim.Claim memory v = _voucher(alice, 1, ACCOUNT_A);
        bytes memory sig = _sign(signerKey, v);
        vm.startPrank(alice);
        wl.claim(v, sig);
        vm.expectRevert(WhitelistClaim.WrongAllocation.selector);
        wl.claim(v, sig);
        vm.stopPrank();
        assertEq(wl.spotsLeft(), 999);
    }

    function test_claim_revertsWithAccountLimit_onAThirdWallet() public {
        /* Scenario:
           Given an account that has claimed two allocations over two wallets
           When a third wallet claims for the same account
           Then it reverts with AccountLimit */
        _claim(alice, 1, ACCOUNT_A);
        _claim(bob, 1, ACCOUNT_A);
        _expectClaimRevert(carol, 1, ACCOUNT_A, WhitelistClaim.AccountLimit.selector);
    }

    function test_claim_checksRunInTheSpecifiedOrder() public {
        /* Scenario:
           Given a voucher that fails several checks at once
           When it is presented
           Then the first failing check in the order NotClaimant, BadSigner, Expired,
             CampaignClosed names the revert */
        WhitelistClaim.Claim memory v = _voucher(alice, 1, ACCOUNT_A);
        (, uint256 otherKey) = makeAddrAndKey("impostor");
        bytes memory badSig = _sign(otherKey, v);
        vm.warp(CLOSE_AT + 1);

        vm.prank(bob);
        vm.expectRevert(WhitelistClaim.NotClaimant.selector);
        wl.claim(v, badSig);

        vm.prank(alice);
        vm.expectRevert(WhitelistClaim.BadSigner.selector);
        wl.claim(v, badSig);

        bytes memory sig = _sign(signerKey, v);
        vm.prank(alice);
        vm.expectRevert(WhitelistClaim.Expired.selector);
        wl.claim(v, sig);
    }

    function test_reads_constantsAndConfiguration() public view {
        /* Scenario:
           Given a freshly deployed registry
           When its reads are called
           Then TOTAL_SPOTS is 1,000, both limits are 2, spotsLeft is 1,000, and signer, openAt,
             closeAt and owner are the constructor's values */
        assertEq(wl.TOTAL_SPOTS(), 1000);
        assertEq(wl.MAX_PER_WALLET(), 2);
        assertEq(wl.MAX_PER_ACCOUNT(), 2);
        assertEq(wl.CLAIM_TYPEHASH(), CLAIM_TYPEHASH);
        assertEq(wl.spotsLeft(), 1000);
        assertEq(wl.signer(), signer);
        assertEq(wl.openAt(), OPEN_AT);
        assertEq(wl.closeAt(), CLOSE_AT);
        assertEq(wl.owner(), admin);
    }

    function test_eip712Domain_namesTheRegistry() public view {
        /* Scenario:
           Given the registry
           When eip712Domain is read
           Then it names "WhitelistClaim" version "1" on this chain at this address */
        (, string memory name, string memory version, uint256 chainId, address verifying,,) = wl.eip712Domain();
        assertEq(name, "WhitelistClaim");
        assertEq(version, "1");
        assertEq(chainId, block.chainid);
        assertEq(verifying, address(wl));
    }

    function test_claimants_pagesAreClamped() public {
        /* Scenario:
           Given three claimants
           When claimants is read with a page that runs past the end, or starts past it
           Then the page is short or empty rather than reverting */
        assertEq(wl.claimants(0, 10).length, 0);
        _claim(alice, 1, ACCOUNT_A);
        _claim(bob, 1, ACCOUNT_B);
        _claim(carol, 1, keccak256("getminted:account-c"));

        WhitelistClaim.Claimant[] memory page = wl.claimants(1, 10);
        assertEq(page.length, 2);
        assertEq(page[0].wallet, bob);
        assertEq(page[1].wallet, carol);
        assertEq(wl.claimants(0, 2).length, 2);
        assertEq(wl.claimants(3, 10).length, 0);
        assertEq(wl.claimants(7, 10).length, 0);
        assertEq(wl.claimants(2, type(uint256).max).length, 1);
    }

    function test_setSigner_byOwner_rotatesTheSigner() public {
        /* Scenario:
           Given a voucher from the current signer
           When the owner sets a new signer
           Then SignerSet is emitted, the old voucher reverts with BadSigner and a voucher from
             the new signer claims */
        WhitelistClaim.Claim memory v = _voucher(alice, 1, ACCOUNT_A);
        bytes memory oldSig = _sign(signerKey, v);
        (address next, uint256 nextKey) = makeAddrAndKey("nextSigner");

        vm.expectEmit(true, true, true, true, address(wl));
        emit SignerSet(next);
        vm.prank(admin);
        wl.setSigner(next);
        assertEq(wl.signer(), next);

        vm.prank(alice);
        vm.expectRevert(WhitelistClaim.BadSigner.selector);
        wl.claim(v, oldSig);

        bytes memory sig = _sign(nextKey, v);
        vm.prank(alice);
        wl.claim(v, sig);
        assertEq(wl.claimsOf(alice), 1);
    }

    function test_setSigner_revertsForZeroOrNonOwner() public {
        /* Scenario:
           Given the registry
           When the owner sets the zero signer, or anyone else sets a signer
           Then it reverts with ZeroSigner or Unauthorized */
        vm.prank(admin);
        vm.expectRevert(WhitelistClaim.ZeroSigner.selector);
        wl.setSigner(address(0));

        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        wl.setSigner(alice);
    }

    function test_setWindow_byOwner_movesTheWindow() public {
        /* Scenario:
           Given the campaign window
           When the owner sets a new window
           Then WindowSet is emitted and openAt and closeAt read the new values */
        vm.expectEmit(true, true, true, true, address(wl));
        emit WindowSet(OPEN_AT + 1 days, CLOSE_AT + 1 days);
        vm.prank(admin);
        wl.setWindow(OPEN_AT + 1 days, CLOSE_AT + 1 days);
        assertEq(wl.openAt(), OPEN_AT + 1 days);
        assertEq(wl.closeAt(), CLOSE_AT + 1 days);
    }

    function test_setWindow_revertsForAnEmptyWindowOrNonOwner() public {
        /* Scenario:
           Given the registry
           When the owner sets a window that does not open before it closes, or anyone else sets one
           Then it reverts with InvalidWindow or Unauthorized */
        vm.startPrank(admin);
        vm.expectRevert(WhitelistClaim.InvalidWindow.selector);
        wl.setWindow(OPEN_AT, OPEN_AT);
        vm.expectRevert(WhitelistClaim.InvalidWindow.selector);
        wl.setWindow(CLOSE_AT, OPEN_AT);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        wl.setWindow(OPEN_AT, CLOSE_AT);
    }

    function test_constructor_revertsForZeroOwnerZeroSignerOrEmptyWindow() public {
        /* Scenario:
           Given deployment arguments with a zero owner, a zero signer, or a window that does not
             open before it closes
           When the registry is deployed
           Then it reverts with NewOwnerIsZeroAddress, ZeroSigner or InvalidWindow */
        vm.expectRevert(Ownable.NewOwnerIsZeroAddress.selector);
        new WhitelistClaim(address(0), signer, OPEN_AT, CLOSE_AT);
        vm.expectRevert(WhitelistClaim.ZeroSigner.selector);
        new WhitelistClaim(admin, address(0), OPEN_AT, CLOSE_AT);
        vm.expectRevert(WhitelistClaim.InvalidWindow.selector);
        new WhitelistClaim(admin, signer, CLOSE_AT, OPEN_AT);
    }

    function test_transferOwnership_handsTheOwnerFunctionsOver() public {
        /* Scenario:
           Given MINT's admin as owner
           When it transfers ownership to another address
           Then the new owner can set the signer and the old one cannot */
        address next = makeAddr("nextAdmin");
        vm.prank(admin);
        wl.transferOwnership(next);
        assertEq(wl.owner(), next);

        vm.prank(admin);
        vm.expectRevert(Ownable.Unauthorized.selector);
        wl.setSigner(alice);

        vm.prank(next);
        wl.setSigner(alice);
        assertEq(wl.signer(), alice);
    }
}

/// @dev WL-1. The campaign rules as the contract enforces them: two per wallet, two per account,
///      allocations in order, one call per allocation, and a sell-out that fails whole.
contract WhitelistClaimRulesTest is WhitelistClaimBase {
    function test_claim_secondAllocation_reachesBothLimits() public {
        /* Scenario: WL-1 — Two per wallet, two per account
           Given a wallet holding one claimed allocation and an account holding one
           When the wallet claims allocation 2 with a valid voucher
           Then the claim succeeds and both counts read 2
           And a third claim for either reverts */
        _claim(alice, 1, ACCOUNT_A);
        assertEq(wl.claimsOf(alice), 1);
        assertEq(wl.accountClaims(ACCOUNT_A), 1);

        _claim(alice, 2, ACCOUNT_A);
        assertEq(wl.claimsOf(alice), 2);
        assertEq(wl.accountClaims(ACCOUNT_A), 2);

        _expectClaimRevert(alice, 3, ACCOUNT_B, WhitelistClaim.WalletLimit.selector);
        _expectClaimRevert(bob, 1, ACCOUNT_A, WhitelistClaim.AccountLimit.selector);
        assertEq(wl.spotsLeft(), 998);
    }

    function test_claim_oneCallPerAllocation_theSecondLater() public {
        /* Scenario:
           Given a holder at $75 who has claimed allocation 1
           When the holder reaches $100 later in the campaign and claims allocation 2
           Then the wallet holds two allocations and appears once in the claimant list */
        _claim(alice, 1, ACCOUNT_A);
        vm.warp(block.timestamp + 5 days);
        _claim(alice, 2, ACCOUNT_A);

        WhitelistClaim.Claimant[] memory rows = wl.claimants(0, 10);
        assertEq(rows.length, 1);
        assertEq(rows[0].wallet, alice);
        assertEq(rows[0].allocations, 2);
    }

    function test_claim_accountSpreadOverWallets_isCappedAtTwo() public {
        /* Scenario:
           Given an account that has claimed one allocation for each of two wallets
           When it claims for either wallet again, or for a third wallet
           Then every attempt reverts with AccountLimit */
        _claim(alice, 1, ACCOUNT_A);
        _claim(bob, 1, ACCOUNT_A);
        _expectClaimRevert(alice, 2, ACCOUNT_A, WhitelistClaim.AccountLimit.selector);
        _expectClaimRevert(bob, 2, ACCOUNT_A, WhitelistClaim.AccountLimit.selector);
        _expectClaimRevert(carol, 1, ACCOUNT_A, WhitelistClaim.AccountLimit.selector);
        assertEq(wl.accountClaims(ACCOUNT_A), 2);
    }

    function test_claim_walletCountsAllocations_notAccounts() public {
        /* Scenario:
           Given a wallet holding one allocation claimed under one account
           When it claims allocation 2 under another account
           Then the claim succeeds: the wallet holds two and each account one */
        _claim(alice, 1, ACCOUNT_A);
        _claim(alice, 2, ACCOUNT_B);
        assertEq(wl.claimsOf(alice), 2);
        assertEq(wl.accountClaims(ACCOUNT_A), 1);
        assertEq(wl.accountClaims(ACCOUNT_B), 1);
    }

    function test_claim_afterTheLastSpot_failsWhole() public {
        /* Scenario:
           Given 999 allocations claimed and a wallet holding one
           When two claims race for the last spot
           Then the first takes spot 1,000, the second reverts with SoldOut and leaves no count,
             claimant row or event behind */
        for (uint256 i; i < 499; ++i) {
            address wallet = makeAddr(string(abi.encode("claimant", i)));
            bytes32 account = keccak256(abi.encode("account", i));
            _claim(wallet, 1, account);
            _claim(wallet, 2, account);
        }
        _claim(alice, 1, ACCOUNT_A);
        assertEq(wl.spotsLeft(), 1);

        WhitelistClaim.Claim memory v = _voucher(bob, 1, ACCOUNT_B);
        bytes memory sig = _sign(signerKey, v);
        vm.expectEmit(true, true, true, true, address(wl));
        emit WhitelistClaimed(bob, 1, ACCOUNT_B, 1000);
        vm.prank(bob);
        wl.claim(v, sig);

        _expectClaimRevert(alice, 2, ACCOUNT_A, WhitelistClaim.SoldOut.selector);
        assertEq(wl.claimsOf(alice), 1);
        assertEq(wl.accountClaims(ACCOUNT_A), 1);
        assertEq(wl.spotsLeft(), 0);
        assertEq(wl.claimants(0, 1000).length, 501);
    }
}

/// @dev WL-4. The claimant list is the whitelist stage's allowlist: exported page by page, turned
///      into SeaDrop allowlist leaves `keccak256(abi.encode(minter, mintParams))` with each
///      wallet's allocations as its per-wallet limit, and minted against on a SeaDrop deployed
///      here. Studio's own step from CSV to root is rehearsal item 3 (`docs/HANDOVER.md`).
contract WhitelistClaimExportTest is WhitelistClaimBase {
    SeaDrop internal seaDrop;
    MintABear internal bears;

    address internal dave = makeAddr("dave");
    address internal feeRecipient = makeAddr("feeRecipient");

    function setUp() public override {
        super.setUp();
        seaDrop = new SeaDrop();
        address[] memory allowed = new address[](1);
        allowed[0] = address(seaDrop);
        bears = new MintABear("MintABear", "BEAR", allowed);
        bears.setMaxSupply(4444);
    }

    /// @dev The whitelist stage's parameters, with `allocations` as the per-wallet limit.
    function _stage(uint256 allocations) internal pure returns (MintParams memory) {
        return MintParams({
            mintPrice: 0,
            maxTotalMintableByWallet: allocations,
            startTime: uint256(CLOSE_AT) + 2 days,
            endTime: uint256(CLOSE_AT) + 3 days,
            dropStageIndex: 1,
            maxTokenSupplyForStage: 4444,
            feeBps: 0,
            restrictFeeRecipients: false
        });
    }

    /// @dev Reads the whole claimant list in pages of `pageSize`, stopping at the first short page.
    function _export(uint256 pageSize) internal view returns (WhitelistClaim.Claimant[] memory all) {
        all = new WhitelistClaim.Claimant[](0);
        for (uint256 offset;; offset += pageSize) {
            WhitelistClaim.Claimant[] memory page = wl.claimants(offset, pageSize);
            WhitelistClaim.Claimant[] memory grown = new WhitelistClaim.Claimant[](all.length + page.length);
            for (uint256 i; i < all.length; ++i) {
                grown[i] = all[i];
            }
            for (uint256 i; i < page.length; ++i) {
                grown[all.length + i] = page[i];
            }
            all = grown;
            if (page.length < pageSize) break;
        }
    }

    function _mintAllowList(address minter, uint256 quantity, uint256 allocations, bytes32[] memory proof) internal {
        vm.prank(minter);
        seaDrop.mintAllowList(address(bears), feeRecipient, address(0), quantity, _stage(allocations), proof);
    }

    function test_export_isTheAllowlist() public {
        /* Scenario: WL-4 — The export is the allowlist
           Given a closed campaign
           When claimants(offset, limit) is read across the whole list
           Then every wallet appears once with its allocation count, and the Studio allowlist
             loaded from it carries the same rows */
        _claim(alice, 1, ACCOUNT_A);
        _claim(bob, 1, ACCOUNT_B);
        _claim(alice, 2, ACCOUNT_A);
        _claim(carol, 1, keccak256("getminted:account-c"));
        vm.warp(uint256(CLOSE_AT) + 1);

        WhitelistClaim.Claimant[] memory rows = _export(2);
        assertEq(rows.length, 3);
        assertEq(rows[0].wallet, alice);
        assertEq(rows[0].allocations, 2);
        assertEq(rows[1].wallet, bob);
        assertEq(rows[1].allocations, 1);
        assertEq(rows[2].wallet, carol);
        assertEq(rows[2].allocations, 1);
        uint256 total;
        for (uint256 i; i < rows.length; ++i) {
            assertEq(rows[i].allocations, wl.claimsOf(rows[i].wallet));
            total += rows[i].allocations;
        }
        assertEq(total, wl.TOTAL_SPOTS() - wl.spotsLeft());

        bytes32[] memory leaves = new bytes32[](rows.length);
        for (uint256 i; i < rows.length; ++i) {
            leaves[i] = keccak256(abi.encode(rows[i].wallet, _stage(rows[i].allocations)));
        }
        bytes32[] memory tree = MerkleTreeLib.build(leaves);
        bears.updateAllowList(
            address(seaDrop),
            AllowListData({merkleRoot: MerkleTreeLib.root(tree), publicKeyURIs: new string[](0), allowListURI: ""})
        );
        vm.warp(uint256(CLOSE_AT) + 2 days);

        for (uint256 i; i < rows.length; ++i) {
            bytes32[] memory proof = MerkleTreeLib.leafProof(tree, i);
            _mintAllowList(rows[i].wallet, rows[i].allocations, rows[i].allocations, proof);
            assertEq(bears.balanceOf(rows[i].wallet), rows[i].allocations);

            vm.expectRevert(
                abi.encodeWithSelector(
                    SeaDropErrorsAndEvents.MintQuantityExceedsMaxMintedPerWallet.selector,
                    rows[i].allocations + 1,
                    rows[i].allocations
                )
            );
            _mintAllowList(rows[i].wallet, 1, rows[i].allocations, proof);
        }

        bytes32[] memory aliceProof = MerkleTreeLib.leafProof(tree, 0);
        vm.expectRevert(SeaDropErrorsAndEvents.InvalidProof.selector);
        _mintAllowList(dave, 1, 2, aliceProof);
        vm.expectRevert(SeaDropErrorsAndEvents.InvalidProof.selector);
        _mintAllowList(bob, 1, 2, MerkleTreeLib.leafProof(tree, 1));

        assertEq(bears.totalSupply(), total);
    }

    function test_export_afterASellOut_listsEveryClaimant() public {
        /* Scenario:
           Given a campaign that sold out before its window closed
           When claimants is read in pages of 100
           Then 500 rows come back, each wallet once with two allocations, totalling 1,000 */
        for (uint256 i; i < 500; ++i) {
            address wallet = makeAddr(string(abi.encode("claimant", i)));
            bytes32 account = keccak256(abi.encode("account", i));
            _claim(wallet, 1, account);
            _claim(wallet, 2, account);
        }
        assertEq(wl.spotsLeft(), 0);

        WhitelistClaim.Claimant[] memory rows = _export(100);
        assertEq(rows.length, 500);
        uint256 total;
        for (uint256 i; i < rows.length; ++i) {
            assertEq(rows[i].wallet, makeAddr(string(abi.encode("claimant", i))));
            assertEq(rows[i].allocations, 2);
            total += rows[i].allocations;
        }
        assertEq(total, 1000);
    }
}
