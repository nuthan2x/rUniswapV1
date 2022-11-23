// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Utils} from "./utils/Utils.sol";
import {Faucet} from "../../contracts/Faucet.sol";
import {MockERC20} from "../../contracts//MockERC20.sol";

contract BaseSetup is Test {
   Utils internal utils;
   Faucet internal faucet;
   MockERC20 internal token;

   address payable[] internal users;
   address internal owner;
   address internal dev;
   uint256 internal faucetBal = 1000;

   function setUp() public virtual {
       utils = new Utils();
       users = utils.createUsers(2);
       owner = users[0];
       vm.label(owner, "Owner");
       dev = users[1];
       vm.label(dev, "Developer");

       token = new MockERC20();
       faucet = new Faucet(IERC20(token));
       token.mint(address(faucet), faucetBal);
   }
}

contract FaucetTest is BaseSetup{
    uint amount_todrip = 1;

    function setUp() override  public {
        super.setUp();
    }

    function test_drip_token()  public {
        console.log('drip and transfering tokens');

        faucet.setLimit(200);
        assertEq(faucet.limit(), 200);

        uint devBal_BeforeDrip = token.balanceOf(dev);

        assertEq(devBal_BeforeDrip,0);

        faucet.drip(dev, 150);

        uint devBal_AfterDrip = token.balanceOf(dev);

        assertEq(devBal_AfterDrip - devBal_BeforeDrip, 150);
    }

    function test_drip_revertIfThrottled() public {
      console.log('expecting revert');
      faucet.drip(dev, amount_todrip);

      vm.expectRevert(abi.encodePacked('TRY_LATER'));
      faucet.drip(dev, amount_todrip);

   }

   function test_drip_reduceFaucetBalance() public {
       console.log("The faucet balance should be reduced");
       faucet.drip(dev, amount_todrip);
       assertEq(token.balanceOf(address(faucet)), faucetBal - amount_todrip);
   }

   function test_fuzzDrip_transfer(address _recepient, uint _amount)  public  {
       console.log('fuzzing now');
       
       vm.assume(_recepient != address(0));
       vm.assume(_amount <= 100);

       faucet.drip(dev, amount_todrip);
       assertEq(token.balanceOf(address(faucet)), faucetBal - amount_todrip);
       assertEq(token.balanceOf(dev), amount_todrip);
   }

   function test_setLimit()  public {
       console.log('setting limit');

       vm.prank(dev);
       vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
       faucet.setLimit(200);

       console.log('msg.sender: ', msg.sender);
       console.log('owner: ', owner);
       console.log('dev: ', dev);

       faucet.setLimit(200);
       assertEq(faucet.limit(), 200);

       
   }
}