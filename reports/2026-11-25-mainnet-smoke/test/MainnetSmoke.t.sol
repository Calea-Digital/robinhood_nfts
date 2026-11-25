// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

interface ISeaDrop {
    function mintPublic(address nftContract, address feeRecipient, address minterIfNotPayer, uint256 quantity)
        external
        payable;
}

interface IBear {
    function ownerOf(uint256) external view returns (address);
    function totalSupply() external view returns (uint256);
    function transferNonce(uint256) external view returns (uint64);
    function transferFrom(address, address, uint256) external;
    function setApprovalForAll(address, bool) external;
}

interface IActivation {
    function setPaused(bool) external;
    function burn(uint256 tokenId, uint128 amount) external;
    function levelOf(uint256) external view returns (uint8);
    function weightOf(uint256) external view returns (uint16);
    function cumulativeOf(uint256) external view returns (uint128);
}

interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/// @notice Smoke test of the live mainnet MintABear + Activation on a fork of 4663. Nothing is broadcast:
///         the admin's unpause exists only on the fork.
contract MainnetSmokeTest is Test {
    address constant SEADROP = 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;
    IBear constant BEARS = IBear(0x655e88103f77a48E0b7875511318d3c5f79FcB28);
    IActivation constant ACT = IActivation(0xAbd272C95F20B59659E3E21Ed75A58652e93159b);
    IERC20 constant MNTD = IERC20(0x62Ed300A5916aeD339a65E04754392763982a967);
    address constant ADMIN = 0x153052B43c8fD4ec01f14D1Edd8660778daa6141;
    address constant OS_FEE = 0x0000a26b00c1F0DF003000390027140000fAa719;
    address constant SEAPORT = 0x0000000000000068F116a894984e2DB1123eB395;
    uint256 constant PUBLIC_START = 1795716000; // 26 Nov 2026 18:00 UTC

    address a = makeAddr("holderA");
    address b = makeAddr("holderB");

    event TransferNonceAdvanced(uint256 indexed tokenId, uint64 nonce);

    function setUp() public {
        vm.createSelectFork("https://rpc.mainnet.chain.robinhood.com");
        vm.warp(PUBLIC_START + 60);
    }

    function _mint(address who) internal returns (uint256 id) {
        id = BEARS.totalSupply() + 1; // SeaDrop ids start at 1
        vm.prank(who);
        ISeaDrop(SEADROP).mintPublic(address(BEARS), OS_FEE, address(0), 1);
        assertEq(BEARS.ownerOf(id), who, "minted to the caller");
    }

    function test_publicMint_burn_transferResets_returnStaysZero() public {
        uint256 id = _mint(a);
        assertEq(BEARS.transferNonce(id), 0, "mint does not advance the counter");

        vm.prank(a);
        vm.expectRevert(); // MintQuantityExceedsMaxMintedPerWallet
        ISeaDrop(SEADROP).mintPublic(address(BEARS), OS_FEE, address(0), 1);

        deal(address(MNTD), a, 10_000e18);
        vm.prank(a);
        MNTD.approve(address(ACT), type(uint256).max);

        vm.prank(a);
        vm.expectRevert(bytes4(keccak256("ContractPaused()")));
        ACT.burn(id, 1666e18);

        vm.prank(ADMIN); // fork only
        ACT.setPaused(false);

        uint256 supplyBefore = MNTD.totalSupply();
        vm.prank(a);
        ACT.burn(id, 1666e18);
        assertEq(ACT.levelOf(id), 1, "level 1 at 1,666");
        assertEq(ACT.weightOf(id), 110, "weight 110");
        assertEq(MNTD.totalSupply(), supplyBefore - 1666e18, "MNTD burned, not moved");
        assertEq(MNTD.balanceOf(a), 10_000e18 - 1666e18);

        vm.expectEmit(true, false, false, true, address(BEARS));
        emit TransferNonceAdvanced(id, 1);
        vm.prank(a);
        BEARS.transferFrom(a, b, id); // holder's own transfer passes V3
        assertEq(BEARS.transferNonce(id), 1);
        assertEq(ACT.levelOf(id), 0, "level 0 after transfer");
        assertEq(ACT.weightOf(id), 100, "level-0 weight");
        assertEq(ACT.cumulativeOf(id), 0);

        vm.prank(b);
        BEARS.transferFrom(b, a, id); // back to the burner
        assertEq(BEARS.transferNonce(id), 2);
        assertEq(ACT.levelOf(id), 0, "still 0 on return to the burner");
        assertEq(ACT.cumulativeOf(id), 0);
    }

    function test_seaportWithoutSignedZone_isRefused() public {
        uint256 id = _mint(a);
        vm.prank(a);
        BEARS.setApprovalForAll(SEAPORT, true);
        vm.prank(SEAPORT);
        vm.expectRevert(bytes4(keccak256("CreatorTokenTransferValidator__CallerMustBeWhitelisted()")));
        BEARS.transferFrom(a, b, id);
        assertEq(BEARS.ownerOf(id), a);
    }
}
