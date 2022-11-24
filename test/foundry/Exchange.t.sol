// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Utils} from "./utils/Utils.sol";
import "../../contracts/MOCK_ERC20.sol";
import "../../contracts/Exchange.sol";
import "../../contracts/Factory.sol";

contract BaseSetup is Test {
   Utils internal utils;
   Exchange internal exchange;
   Exchange internal exchange2;

   MOCK_ERC20 internal token;  // MOCK token
   MOCK_ERC20 internal token2; // ROCK token
   Factory internal factory;

   address payable[] internal users;
   address internal user1;
   address internal user2;

   function setUp() public virtual {
       utils = new Utils();
       users = utils.createUsers(2);
       user1 = users[0];
       vm.label(user1, "user1");
       user2 = users[1];
       vm.label(user2, "user2");

       token = new MOCK_ERC20('MOCK_ERC20','MOCK', 2000e18);
       token2 = new MOCK_ERC20('ROCK_ERC20','ROCK', 2000e18);
       
       factory = new Factory();
       exchange = Exchange(factory.createExchange(address(token)));
       exchange2 = Exchange(factory.createExchange(address(token2)));
       
       token.approve(address(exchange), 2000e18);
       token2.approve(address(exchange2), 2000e18);
   }

}

contract Exchange_Test is BaseSetup {

    function setUp()  override public {
        super.setUp();
    }

    receive() external payable{}

    function test_addLiquidity()  public {
        uint256 deposit = 200e18;
        console.log('exchange.getReserve() before: ', exchange.getReserve());
        exchange.addLiquidity(deposit);

        assertEq(token.balanceOf(address(exchange)), deposit);        

        assertEq(exchange.getReserve(), deposit);
        console.log('exchange.getReserve() after: ', exchange.getReserve());
    }

    // below 2 tests is constant product AMM, so there is a slippage
    // reserves can never go to zero because you are swapping on  x*y =k , 
    // the price will slip to compensate the product of token reserves to be constant

    // below test returns how much tokens you get when a ETH is gave in
    function test_getTokenOut() public {
        vm.deal(address(exchange), 100e18);
        exchange.addLiquidity(200e18);
        
        uint256 ethIn = 1e18;
        uint256 tokenOut = exchange.getTokenAmount(ethIn);
        console.log('tokenOut: ', tokenOut );
        
        // assertEq(tokenOut, 19605);  
        // (19605 / 1e4) = 1.9605 because of decimal precision inside contract

        // 1.9605 tokens will be out if we swap 1 eth in, it will 2 tokens out if its constant sum as it is on constant product we get less here + 1% fees
        // now for next swap , the price of 1 ETH will go even higher and will get only less tokens per ETH in, unless a arbitrager neutralizes that
    }

    // below test returns how much ETH you get when tokens are gave in
    function test_getEthOut() public {
        vm.deal(address(exchange), 100e18);
        exchange.addLiquidity(200e18);
        

        uint256 tokenIn = 2e18;
        uint256 ethOut = exchange.getEthAmount(tokenIn);
        console.log('ethOut: ', ethOut);

        // assertEq(ethOut, 9850);
        // (9850 / 1e4) = 0.9850 because of decimal precision inside contract

        // here the ethOut should be 1 ETH instead of slipped 0.9850 eth + 1%fees
    }



// testing part2 of tutorial

    function test_addLP_swap_removeLP() public {
        vm.deal(address(this), 1000 * 1e18);

        // adding initial liquidity to Exchange contract
        exchange.addLiquidity{value : 100e18}(200e18);
        assertEq(address(exchange).balance, 100e18);
        assertEq(exchange.getReserve(), 200e18);

        //getting price now ( 1 ETH = ?? MOCK tokens)
        uint256 tokensOut1 =  exchange.getTokenAmount(1e18);
        assertEq(tokensOut1, 1960590157441330824);  
        // 1.9605 MOCK tokens/ 1 ETH

        // add liquidity second time
        exchange.addLiquidity{value : 100e18}(200e18);
        //getting price now ( 1 ETH = ?? MOCK tokens)
        uint256 tokensOut2 =  exchange.getTokenAmount(1e18);
        assertEq(tokensOut2, 1970247275983879795); 
        // 1.9702 MOCK tokens/ 1 ETH 
        // as low is the impact of your swap amount on the LP better is the price rate i.e less slippage


        // Swap 2 eth in
        assertEq(token.balanceOf(address(this)), 1600 * 1e18);
        exchange.ethToTokenSwap{value : 2e18}(3e18);
        assertEq(address(exchange).balance, 202 * 1e18); 
        assertEq(token.balanceOf(address(this)), 1603921180314882661649);
        // sent 2 ETH in, got 3.9211.. tokens Out
        // Swap 10 token in
        uint256 ethOut = exchange.getEthAmount(1e18);
        console.log('ethOut: ', ethOut);
        assertEq(address(exchange).balance, 202000000000000000000); // 202 eth reserve 
        assertEq(token.balanceOf(address(exchange)), 396078819685117338351); // 396.078 token reserve 

        assertEq(address(this).balance, 798000000000000000000); 
        // 798 ETH balance in our account i.e this test_contract
        exchange.tokenToEthSwap(1e18, (ethOut) * 98 /100); // 2% slippage allowed
        assertEq(address(this).balance, 798503640653926409305); 
        // 798.503 ETH updated balance after 1 token is swapped in for 0.503 ETH
        // after prev ethToTokenSwap function of adding 2 ETH in and 3.9211 Mock tokens swapped Out,
        // the amount of eth reserve increased and token reserve decreased so ,
        // amount of eth per 1 MOCK token went from 1 token = 0.5 ETH to 1 token = 0.503 ETH as there were 202 ETH in reserve instead of 200 ETH
        // its all about x*y = k
        

        assertEq(token.balanceOf(address(exchange)), 397078819685117338351); // 397.0788 tokens reserve
        // now a external user uses 2 eth to swap to tokens
        vm.startPrank(user1);  // msg.sender == user1
        vm.deal(user1, 100e18);
  
        // Swap 2 eth in
        assertEq(token.balanceOf(user1), 0);
        assertEq(address(user1).balance, 100e18);
        uint256 ethtoToken_withoutfee = (2e18 * token.balanceOf(address(exchange))) / (address(exchange).balance  + 2e18);
        assertEq( ethtoToken_withoutfee, 3902564359982775985);  // 2 ETH = 3.9025 tokens without fees

        exchange.ethToTokenSwap{value : 2e18}(3e18);
        assertEq(token.balanceOf(user1), 3863918469463728663); // 3.8639 tokens out when 2 ETH swapped in (with fees)
        assertEq(address(user1).balance, 98 * 1e18);
        // sent 2 ETH in, got 3.8639.. tokens Out (with fees)
        vm.stopPrank();
        assertEq(token.balanceOf(address(exchange)), 393214901215653609688); // 392.2149 tokens reserve
        // here only 99% of tokens at current price is sent rest 1 percent is kept inside exchange itself
        // so when the LP provvider wants to remove liquidity he gets this a percentage of this fee depending on % of LP share he provided



        // remove Liquidity  msg.sender = address(this)
        uint256 LPrewarded = exchange.balanceOf(address(this));
        assertEq(LPrewarded, 200 * 1e18); 
        // tells us we have 200 ETH-MOCK LP tokens ( that is rewarded when liquidity is added)
        assertEq(address(this).balance, 798503640653926409305);
        assertEq(token.balanceOf(address(this)), 1602921180314882661649);

        exchange.removeLiquidity(200 * 1e18);
        assertEq(exchange.balanceOf(address(this)), 0); // LPburned
        assertEq(address(this).balance, 1002000000000000000000);         
        // 1002 ETH  , before adding liquidity we had 1000ETH in this testing contract account
        // 1996.136  MOCK tokens, before adding liquidity we had 2000 tokens in this testing contract account
        // because when there was liquidity a user1 [user1] made a 2 ETH swap to get out 3.8639 tokens

    }

    function test_LPnameSymbol() public {
        assertEq(exchange.name(), "ETH-MOCK LP");
        assertEq(exchange.symbol(), "ETH-MOCK LP");

    }

    function test_TokenToTokenSwap() public {
        vm.deal(address(this), 1000 * 1e18);

        // adding initial liquidity to Exchange contract
        exchange.addLiquidity{value : 100e18}(200e18);
        exchange2.addLiquidity{value : 100e18}(200e18);

        assertEq(address(exchange).balance, 100e18);
        assertEq(address(exchange2).balance, 100e18);
        assertEq(exchange.getReserve(), 200e18);
        assertEq(exchange2.getReserve(), 200e18);

        //getting price now ( 1 ETH = ?? MOCK tokens)
        uint256 tokensOut1 =  exchange.getTokenAmount(1e18);
        assertEq(tokensOut1, 1960590157441330824);  
        // 1.9605 MOCK tokens/ 1 ETH

        //getting price now ( 1 ETH = ?? ROCK tokens)
        uint256 tokensOut2 =  exchange2.getTokenAmount(1e18);
        assertEq(tokensOut2, 1960590157441330824);  
        // 1.9605 ROCK tokens/ 1 ETH


        // swap 10 MOCK to ROCK  as user1
        vm.deal(address(user1), 100e18);
        token.transfer(address(user1), 10e18);

        vm.startPrank(user1);
        console.log('ROCK.balanceOf(address(this)): before', token2.balanceOf(address(user1))); // 0  ROCK tokens
        console.log('MOCK.balanceOf(address(this)): before', token.balanceOf(address(user1)));  // 10 MOCK tokens
        
        token.approve(address(exchange), 10e18);
        exchange.tokenToTokenSwap(10e18, address(token2), 8e18);

        console.log('ROCK.balanceOf(address(this)): after', token2.balanceOf(address(user1))); // 8.9221 ROCK tokens
        console.log('MOCK.balanceOf(address(this)): after', token.balanceOf(address(user1)));  // 0 MOCK tokens

        // now above tokentotoken token transfer should happen if there is no ether with you and you have token A to swap out to token B
        // lets see how much we get if eth to token B direct swap. ( see next test).
        vm.stopPrank();
    }

    function test_ethToTokenB() public {
        vm.deal(address(this), 1000 * 1e18);

        // adding initial liquidity to Exchange contract
        exchange.addLiquidity{value : 100e18}(200e18);
        exchange2.addLiquidity{value : 100e18}(200e18);

        assertEq(address(exchange).balance, 100e18);
        assertEq(address(exchange2).balance, 100e18);
        assertEq(exchange.getReserve(), 200e18);
        assertEq(exchange2.getReserve(), 200e18);

        //getting price now ( 1 ETH = ?? MOCK tokens)
        uint256 tokensOut1 =  exchange.getTokenAmount(1e18);
        assertEq(tokensOut1, 1960590157441330824);  
        // 1.9605 MOCK tokens/ 1 ETH

        
       // swap 10 MOCK to ROCK  as user1
        vm.deal(address(user1), 100e18);

        vm.startPrank(user1);
        console.log('ROCK.balanceOf(address(this)): before', token2.balanceOf(address(user1))); // 0  ROCK tokens
        console.log('MOCK.balanceOf(address(this)): before', token.balanceOf(address(user1)));  // 0 MOCK tokens
        console.log('address(this).balance: before', address(user1).balance); // 100 ETH
        
        //getting price now ( 1 ETH = ?? ROCK tokens)
        uint256 tokensOut2 =  exchange2.getTokenAmount(5e18);
        assertEq(tokensOut2, 9433063363506431634);  
        uint256 tokensOut3 =  exchange2.getTokenAmount(1e18);
        assertEq(tokensOut3, 1960590157441330824); 
        // 1.8866 ROCK tokens/ 1 ETH when 5ETH swappedin
        // 1.9605 ROCK tokens/ 1 ETH when 1ETH swappedin

        exchange2.ethToTokenSwap{value : 5e18 }(8e18);

        console.log('ROCK.balanceOf(address(this)): after', token2.balanceOf(address(user1))); // 9.43306  ROCK tokens
        console.log('MOCK.balanceOf(address(this)): after', token.balanceOf(address(user1)));  // 0 MOCK tokens
        console.log('address(this).balance: after', address(user1).balance);

        // At this state where a swap of price impact 10% of LP eth to token is better than token to token swap
        // liquidate tokenA at a CEX and get eth then buy token B by eth to tokenB swap
        // there are routers that give best value after slippage/ speed/ gas, some aggregare both CEX & DEX too.
        vm.stopPrank();
    }

}
