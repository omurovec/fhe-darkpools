// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "../src/DarkPool.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        ERC20Mock eth = new ERC20Mock();
        ERC20Mock usdc = new ERC20Mock();
        eth.mint(address(this), 100 ether);
        usdc.mint(address(this), 100 ether);

        // Deploy DarkPool contract
        ERC20[] memory tokens = new ERC20[](2);
        tokens[0] = eth;
        tokens[1] = usdc;
        DarkPool pool = new DarkPool(tokens);

    }
}
