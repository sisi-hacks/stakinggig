// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/access/Ownable.sol";
import "@chainlink/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {console} from "forge-std/Test.sol";

// pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

// pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
    function getAmountsIn(
        uint256 amountOut,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

// pragma solidity >=0.6.2;

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract SeeseaToken is ERC20, ERC20Burnable, ERC20Pausable, Ownable {
    using SafeERC20 for IERC20;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    uint256 immutable usdEntryFee;

    uint256 public _taxFee = 5;

    mapping(address => bool) private _isExcludedFromFee;

    mapping(address => IERC20) public tokens;

    modifier isSupported(address _token) {
        require(address(tokens[_token]) != address(0), "token is not supported");
        _;
    }

    AggregatorV3Interface internal bnbUsdPriceFeed;
    AggregatorV3Interface internal usdBnbPriceFeed;

    constructor(
        address initialOwner,
        address _priceFeedAddress,
        address _priceFeedAddress2,
        address _usdc,
        address _usdt
    ) ERC20("Seesea Token", "SSAI") Ownable(initialOwner) {
        // console.log("this is minted to owner", 100_000_000 * 10 ** decimals());
        _mint(msg.sender, 100_000_000 * 10 ** decimals());

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        usdEntryFee = 5 * (10 ** 15); // 0.005
        bnbUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        usdBnbPriceFeed = AggregatorV3Interface(_priceFeedAddress2);

        // Store supported assets
        tokens[_usdc] = IERC20(_usdc);
        tokens[_usdt] = IERC20(_usdt);

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        if (takeFee) {
            uint256 fee = calculateTaxFee(value);
            uint256 newValue = value - fee;
            super._update(from, to, newValue);
            super._update(from, owner(), fee); // Transfer the fee to the owner
        } else {
            super._update(from, to, value);
        }

        super._update(from, to, value);
    }

    function setTaxFeePercent(uint256 taxFee) external onlyOwner {
        _taxFee = taxFee;
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount * (_taxFee / 10 ** 2);
    }

    function swapTokensForBNB(uint256 tokenAmount) external whenNotPaused {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) public onlyOwner {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function withdrawTokens(uint256 amount, address token) external onlyOwner isSupported(token) whenNotPaused {
        require(amount >= IERC20(token).balanceOf(address(this)), "Not enough tokens!");
        IERC20(token).transfer(owner(), amount);
    }

    function withdrawBNB() external onlyOwner whenNotPaused {
        (bool success,) = owner().call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    function buyTokensBNB() public payable whenNotPaused {
        require(msg.value < getBnbUsdPrice(), "You need to send some more BNB");

        uint256 tokenAmount = msg.value;

        // Check if the owner's balance is sufficient
        uint256 ownerBalance = super.balanceOf(owner());
        console.log("owners balace", ownerBalance);
        require(ownerBalance >= tokenAmount, "Owner does not have enough tokens");

        // Transfer tokens from owner to buyer
        _transfer(owner(), msg.sender, tokenAmount);
    }

    function buyTokens(address token, uint256 amount) external isSupported(token) whenNotPaused {
        require(amount < getUsdBnbPrice(), "Not enough tokens!");

        bool success = tokens[token].transferFrom(msg.sender, address(this), amount);
        require(success, "transferFrom failed");

        // Check if the owner's balance is sufficient
        uint256 ownerBalance = balanceOf(owner());
        require(ownerBalance >= amount, "Owner does not have enough tokens");

        // Transfer tokens from owner to buyer
        _transfer(owner(), msg.sender, amount);
    }

    function getUsdBnbPrice() public view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = bnbUsdPriceFeed.latestRoundData();
        require(price > 0, "price has to be a positive number");
        require(updatedAt > block.timestamp - 60 * 60, "stale price feed"); // 1 hour
        uint256 adjustedPrice = uint256(price) * 10 ** 10; // 18 decimals
        // $0.005 / BNB
        uint256 costToEnter = (usdEntryFee * 10 ** 18) / adjustedPrice;
        return costToEnter;
    }

    function getBnbUsdPrice() public view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = usdBnbPriceFeed.latestRoundData();
        require(price > 0, "price has to be a positive number");
        require(updatedAt > block.timestamp - 60 * 60, "stale price feed"); // 1 hour
        uint256 adjustedPrice = uint256(price) * 10 ** 10; // 18 decimals
        // $0.0008 / USD
        uint256 costToEnter = (usdEntryFee * 10 ** 18) / adjustedPrice;
        return costToEnter;
    }

    //to recieve BNB
    receive() external payable {}
}
