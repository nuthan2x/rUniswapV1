// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IFactory {
  function getExchange(address _tokenAddress) external returns (address);
}

contract Exchange is ERC20 {
    address public tokenAddress;
    address public factoryAddress;

    constructor(address _token) ERC20(getLPtoken(_token), getLPtoken(_token) ) {
        require(_token != address(0),"invalid token address");
        tokenAddress = _token;
        factoryAddress = msg.sender;
    }

    function addLiquidity(uint256 _tokenAmount) public payable returns (uint256) {

        if (getReserve() == 0) {
            IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokenAmount);

            uint256 liquidity = address(this).balance;
            _mint(msg.sender, liquidity);

            return(liquidity);

        }else {
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = getReserve();

            uint256 tokenstoAdd = (tokenReserve * msg.value) / ethReserve ;
            require(tokenstoAdd >= _tokenAmount,"");

            IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokenAmount);

            uint256 liquidity = (totalSupply()  *  msg.value) / ethReserve ;
            _mint(msg.sender, liquidity);

            return(liquidity);
        }
    }

    function removeLiquidity(uint256 _amount) public returns (uint256, uint256) {
        require(_amount > 0, "can't request zero amount");

        uint256 ethOut = _amount * address(this).balance / totalSupply() ;
        uint256 tokensOut = _amount * getReserve() / totalSupply() ;
        _burn(msg.sender, _amount);

        payable(msg.sender).transfer(ethOut);
        IERC20(tokenAddress).transfer(msg.sender, tokensOut);

        return(ethOut, tokensOut);
    }

    function getReserve() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }


    function getTokenAmount(uint256 _ethSold) public view  returns (uint256) {
        require(_ethSold > 0, "ethSold is too small");

        uint256 tokenReserve = getReserve();

        return getAmount(_ethSold, address(this).balance, tokenReserve);
    }

    function getEthAmount(uint256 _tokenSold) public view  returns (uint256) {
        require(_tokenSold > 0, "tokenSold is too small");

        uint256 tokenReserve = getReserve();

        return getAmount(_tokenSold, tokenReserve, address(this).balance);
    }

    function ethToToken(uint256 _minTokensOut, address recepient) private {
        uint256 tokenReserve = getReserve();

        // we need to subtract msg.value from contract’s balance because by the time the function is called 
        // the ethers sent have already been added to its balance.
        uint256 tokensOut = getAmount(msg.value, address(this).balance - msg.value, tokenReserve);
        require(tokensOut >= _minTokensOut, "insufficient output amount");
        
        IERC20(tokenAddress).transfer(recepient, tokensOut);
    }

    function ethToTokenSwap(uint256 _minTokensOut) public payable{
        ethToToken(_minTokensOut, msg.sender);
    }

    function ethToTokenTransfer(uint256 _minTokensOut, address recepient) public payable{
        ethToToken(_minTokensOut, recepient);
    }

    function tokenToEthSwap(uint256 tokensIn, uint256 _minEthOut) public {
        uint256 ethOut = getEthAmount(tokensIn);

        require(ethOut >= _minEthOut, "insufficient output amount");

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), tokensIn);
        payable(msg.sender).transfer(ethOut);
    }

    function tokenToTokenSwap(uint256 tokensIn, address tokensOutAddress, uint256 _minTokensOut) public {
        address exchangeAddress = IFactory(factoryAddress).getExchange(tokensOutAddress);
        require(exchangeAddress != address(this) && exchangeAddress != address(0), "invalid exchange address");

        uint256 tokenReserve = getReserve();
        uint256 ethOut = getAmount(tokensIn, tokenReserve, address(this).balance);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), tokensIn );
        
        Exchange(exchangeAddress).ethToTokenTransfer{value : ethOut}(_minTokensOut, msg.sender);
    }

    function getAmount(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) private pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
        
        // 1% trading fee
        uint256 inputAmountwithfee = inputAmount * 99;
        uint256 numerator = inputAmountwithfee * outputReserve ;
        uint256 denominator = (inputReserve * 100) + inputAmountwithfee ;

        return numerator / denominator ;
    }

    function getLPtoken(address _token) public view returns (string memory LPtoken) {
        // bytes memory _name = bytes( ERC20(_token).name()) ;
        bytes memory _symbol = bytes( ERC20(_token).symbol()) ;

        LPtoken = string( bytes.concat( bytes('ETH-'), bytes(_symbol), bytes(' LP')) );
    }
}