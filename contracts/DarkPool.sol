// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "fhevm/lib/TFHE.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./abstracts/EIP712WithModifier.sol";

contract DarkPool is EIP712WithModifier {
    // Buy or Sell base token for quote token
    enum OrderType {
        Buy,
        Sell
    }

    struct Order {
        euint32 amount; // Amount of base to buy/sell
        euint32 price; // Price of base asset to buy/sell at (e.g 2000 USDC/ETH)
    }

    // [ base, quote ] (e.g. [ ETH, USDC ])
    ERC20[] public tokens;
    uint8 public constant BASE_INDEX = 0;
    uint8 public constant QUOTE_INDEX = 1;

    // user => token => balance
    mapping(address => mapping(uint8 => euint32)) public balances;
    // user => buy/sell => sellorder
    mapping(address => mapping(OrderType => Order)) public orders;

    event OrderCreated(
        address indexed user,
        uint8 orderType,
        euint32 amount,
        euint32 price
    );

    event OrderUpdated(
        address indexed user,
        uint8 orderType,
        euint32 amount,
        euint32 price
    );

    event OrderDeleted(address indexed user, uint8 orderType);

    constructor(ERC20[] memory _tokens) EIP712WithModifier("DarkPool", "1") {
        tokens = _tokens;
    }

    function deposit(uint8 tokenId, uint32 amount) public {
        tokens[tokenId].transferFrom(msg.sender, address(this), amount);

        euint32 prevBalance = balances[msg.sender][tokenId];
        balances[msg.sender][tokenId] = TFHE.add(prevBalance, amount);
    }

    function _createOrder(
        OrderType orderType,
        euint32 amount,
        euint32 price
    ) internal {
        // ensure there is no existing order
        require(
            !TFHE.isInitialized(
                TFHE.ne(orders[msg.sender][orderType].amount, uint32(0))
            ),
            "Cannot create order, existing order exists"
        );

        // ensure user has enough balance, if not, the max balance is used
        euint32 safeAmount;

        if (orderType == OrderType.Buy) {
            safeAmount = TFHE.cmux(
                TFHE.le(
                    TFHE.mul(amount, price),
                    balances[msg.sender][QUOTE_INDEX]
                ),
                amount,
                TFHE.asEuint32(0)
            );
        } else {
            // ensure amount <= base balance
            safeAmount = TFHE.cmux(
                TFHE.le(amount, balances[msg.sender][BASE_INDEX]),
                amount,
                TFHE.asEuint32(0)
            );
        }

        orders[msg.sender][orderType] = Order(safeAmount, price);
        // create sell order
        emit OrderCreated(msg.sender, uint8(orderType), amount, price);
    }

    function createOrder(
        OrderType orderType,
        bytes calldata amountCypherText,
        bytes calldata priceCypherText
    ) public {
        euint32 amount = TFHE.asEuint32(amountCypherText);
        euint32 price = TFHE.asEuint32(priceCypherText);

        _createOrder(orderType, amount, price);
    }

    function fillOrder(address buyer, address seller) public {
        Order memory buyOrder = orders[buyer][OrderType.Buy];
        Order memory sellOrder = orders[seller][OrderType.Sell];

        // Check which order is larger
        euint32 buyOrderLarger = TFHE.le(sellOrder.amount, buyOrder.amount);

        // Get the amount being traded, if prices are not equal, baseAmount will be 0
        euint32 baseAmount = TFHE.cmux(
            TFHE.eq(buyOrder.price, sellOrder.price),
            TFHE.cmux(buyOrderLarger, sellOrder.amount, buyOrder.amount),
            TFHE.asEuint32(0)
        );
        euint32 quoteAmount = TFHE.mul(baseAmount, sellOrder.price); // note that buyOrder.price == sellOrder.price

        /* Adjust order amounts */
        // Subtract amount filled from each order
        orders[buyer][OrderType.Buy].amount = TFHE.sub(
            buyOrder.amount,
            baseAmount
        );
        orders[seller][OrderType.Sell].amount = TFHE.sub(
            sellOrder.amount,
            baseAmount
        );

        // Adjust base balances
        balances[seller][BASE_INDEX] = TFHE.sub(
            balances[seller][BASE_INDEX],
            baseAmount
        );
        balances[buyer][BASE_INDEX] = TFHE.add(
            balances[buyer][BASE_INDEX],
            baseAmount
        );

        // Adjust quote balances
        balances[seller][QUOTE_INDEX] = TFHE.add(
            balances[seller][QUOTE_INDEX],
            quoteAmount
        );
        balances[buyer][QUOTE_INDEX] = TFHE.sub(
            balances[buyer][QUOTE_INDEX],
            quoteAmount
        );

        // Remove price of filled orders
        orders[buyer][OrderType.Buy].price = TFHE.cmux(
            TFHE.le(buyOrder.amount, uint32(0)),
            TFHE.asEuint32(0),
            buyOrder.price
        );
        orders[seller][OrderType.Sell].price = TFHE.cmux(
            TFHE.le(sellOrder.amount, uint32(0)),
            TFHE.asEuint32(0),
            sellOrder.price
        );

        emit OrderUpdated(
            buyer,
            uint8(OrderType.Buy),
            orders[buyer][OrderType.Buy].amount,
            orders[buyer][OrderType.Buy].price
        );
        emit OrderUpdated(
            seller,
            uint8(OrderType.Sell),
            orders[seller][OrderType.Sell].amount,
            orders[seller][OrderType.Sell].price
        );
    }

    // Since we don't have control flow with TFHE,
    // we require users or market makers to delete their
    // orders once they have been filled
    function deleteOrder(address user, OrderType orderType) public {
        Order memory order = orders[user][orderType];

        // ensure order exists
        require(TFHE.isInitialized(order.amount), "Order does not exist");

        // ensure order is empty
        TFHE.req(TFHE.eq(order.amount, uint32(0)));

        // delete order
        delete orders[user][orderType];

        emit OrderDeleted(user, uint8(orderType));
    }

    function retractOrder(OrderType orderType) public {
        delete orders[msg.sender][orderType];
        emit OrderDeleted(msg.sender, uint8(orderType));
    }

    function getBalance(
        uint8 tokenId,
        bytes32 publicKey,
        bytes calldata signature
    )
        public
        view
        onlySignedPublicKey(publicKey, signature)
        returns (bytes memory)
    {
        return TFHE.reencrypt(balances[msg.sender][tokenId], publicKey);
    }

    function withdraw(uint8 tokenId, uint32 amount) public {
        if (tokenId == BASE_INDEX) {
            // ensure the user doesn't have an open sell order
            require(
                !TFHE.isInitialized(orders[msg.sender][OrderType.Sell].amount),
                "Close sell order before withdrawing base"
            );
        } else {
            // ensure the user doesn't have an open buy order
            require(
                !TFHE.isInitialized(orders[msg.sender][OrderType.Buy].amount),
                "Close buy order before withdrawing quote"
            );
        }

        // ensure user has enough balance
        TFHE.req(TFHE.ge(balances[msg.sender][tokenId], amount));

        // transfer tokens
        tokens[tokenId].transfer(msg.sender, amount);

        // update balance
        balances[msg.sender][tokenId] = TFHE.sub(
            balances[msg.sender][tokenId],
            amount
        );
    }
}
