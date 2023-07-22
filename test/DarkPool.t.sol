// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "../src/DarkPool.sol";

contract DarkPoolHarness is DarkPool {
    constructor(ERC20[] memory _tokens) DarkPool(_tokens) {}

    function Test_createOrder(DarkPool.OrderType orderType, euint32 amount, euint32 price) external {
        _createOrder(orderType, amount, price);
    }
}

contract DarkPoolTest is Test {
    address constant alice = address(0x1);
    address constant bob = address(0x2);

    uint256 constant START_BASE_AMOUNT = 10;
    uint256 constant START_QUOTE_AMOUNT = 20000;
    uint256 constant BASE_PRICE = 2000;

    ERC20Mock public eth;
    ERC20Mock public usdc;

    DarkPoolHarness public pool;

    event OrderCreated(address indexed user, uint8 orderType, euint32 amount, euint32 price);

    function setUp() public {
        // Deploy mock token contracts
        eth = new ERC20Mock();
        usdc = new ERC20Mock();

        // Deploy DarkPool contract
        ERC20[] memory tokens = new ERC20[](2);
        tokens[0] = eth;
        tokens[1] = usdc;
        pool = new DarkPoolHarness(tokens);

        // init balances
        eth.mint(alice, START_BASE_AMOUNT);
        usdc.mint(bob, START_QUOTE_AMOUNT);
    }

    function testCreateSellOrder(uint256 baseAmount) public {
        vm.assume(baseAmount <= START_BASE_AMOUNT);

        // Alice deposits
        vm.startPrank(alice);
        eth.approve(address(pool), uint32(baseAmount));
        pool.deposit(pool.BASE_INDEX(), uint32(baseAmount));

        // Alice creates Sell Order
        vm.expectEmit(address(pool));
        emit OrderCreated(
            address(alice),
            uint8(DarkPool.OrderType.Sell),
            TFHE.asEuint32(baseAmount),
            TFHE.asEuint32(BASE_PRICE)
        );
        pool.Test_createOrder(DarkPool.OrderType.Sell, TFHE.asEuint32(uint32(baseAmount)), TFHE.asEuint32(BASE_PRICE));
        vm.stopPrank();
    }

    function testCreateBuyOrder(uint256 quoteAmount) public {
        vm.assume(quoteAmount <= START_QUOTE_AMOUNT);

        // Bob deposits
        vm.startPrank(bob);
        usdc.approve(address(pool), uint32(quoteAmount));
        pool.deposit(pool.QUOTE_INDEX(), uint32(quoteAmount));

        // Bob creates Sell Order
        vm.expectEmit(address(pool));
        emit OrderCreated(
            address(bob),
            uint8(DarkPool.OrderType.Buy),
            TFHE.asEuint32(quoteAmount),
            TFHE.asEuint32(BASE_PRICE)
        );
        pool.Test_createOrder(DarkPool.OrderType.Buy, TFHE.asEuint32(uint32(quoteAmount)), TFHE.asEuint32(BASE_PRICE));
        vm.stopPrank();
    }

    function testFlow(uint256 baseAmount) public {
        vm.assume(baseAmount <= START_BASE_AMOUNT);
        uint256 quoteAmount = baseAmount * BASE_PRICE;

        // Alice deposits
        vm.startPrank(alice);
        eth.approve(address(pool), uint32(baseAmount));
        pool.deposit(pool.BASE_INDEX(), uint32(baseAmount));

        // Alice creates Sell Order
        vm.expectEmit(address(pool));
        emit OrderCreated(
            address(alice),
            uint8(DarkPool.OrderType.Sell),
            TFHE.asEuint32(baseAmount),
            TFHE.asEuint32(BASE_PRICE)
        );
        pool.Test_createOrder(DarkPool.OrderType.Sell, TFHE.asEuint32(uint32(baseAmount)), TFHE.asEuint32(BASE_PRICE));
        vm.stopPrank();

        // Bob deposits
        vm.startPrank(bob);
        usdc.approve(address(pool), uint32(quoteAmount));
        pool.deposit(pool.QUOTE_INDEX(), uint32(quoteAmount));

        // Bob creates Buy Order
        pool.Test_createOrder(DarkPool.OrderType.Buy, TFHE.asEuint32(baseAmount), TFHE.asEuint32(BASE_PRICE));
        vm.stopPrank();

        // fill order
        pool.fillOrder(alice, bob);

        // Withdraw new balances
        vm.prank(alice);
        pool.withdraw(pool.QUOTE_INDEX(), uint32(quoteAmount));

        vm.prank(bob);
        pool.withdraw(pool.BASE_INDEX(), uint32(baseAmount));

        // Check balances
        require(eth.balanceOf(address(pool)) == 0);
        require(usdc.balanceOf(address(pool)) == 0);
        require(eth.balanceOf(alice) == START_BASE_AMOUNT - baseAmount);
        emit log_named_uint("alice usdc balance: ", usdc.balanceOf(alice));
        require(usdc.balanceOf(alice) == quoteAmount);
        require(eth.balanceOf(bob) == baseAmount);
        require(usdc.balanceOf(bob) == START_QUOTE_AMOUNT - quoteAmount);
    }
}
