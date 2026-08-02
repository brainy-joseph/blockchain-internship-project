// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTTicket is ERC721, Ownable {

    struct Ticket {
        string eventName;
        uint256 faceValue;
        uint256 maxResalePrice;
        uint256 transferOpensAt;
        bool isRedeemed;
    }

    mapping(uint256 => Ticket) public tickets;
    mapping(uint256 => uint256) public salePrice;
    mapping(uint256 => address) public seller;

    uint256 public nextTokenId;

    constructor() ERC721("NFTTicket", "TICKET") Ownable(msg.sender) {}

    function mintTicket(
        address to,
        string memory eventName,
        uint256 faceValue,
        uint256 maxResalePrice,
        uint256 transferOpensAt
    ) external onlyOwner {
        uint256 tokenId = nextTokenId++;
        
        tickets[tokenId] = Ticket({
            eventName: eventName,
            faceValue: faceValue,
            maxResalePrice: maxResalePrice,
            transferOpensAt: transferOpensAt,
            isRedeemed: false
        });
        
        _safeMint(to, tokenId);
    }

    function listTicket(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(block.timestamp >= tickets[tokenId].transferOpensAt, "Locked: soulbound");
        require(price <= tickets[tokenId].maxResalePrice, "Anti-scalping: price too high");
        require(price > 0, "Price must be > 0");

        salePrice[tokenId] = price;
        seller[tokenId] = msg.sender;
    }

    function buyTicket(uint256 tokenId) external payable {
        uint256 price = salePrice[tokenId];
        address oldOwner = seller[tokenId];
        
        require(price > 0, "Not for sale");
        require(msg.value >= price, "Send exact price");

        salePrice[tokenId] = 0;
        seller[tokenId] = address(0);

        _transfer(oldOwner, msg.sender, tokenId);
        payable(oldOwner).transfer(price);

        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function redeemTicket(uint256 tokenId) external onlyOwner {
        require(!tickets[tokenId].isRedeemed, "Already used");
        tickets[tokenId].isRedeemed = true;
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = super._update(to, tokenId, auth);
        
        if (from != address(0) && to != address(0)) {
            require(
                block.timestamp >= tickets[tokenId].transferOpensAt,
                "Transfer locked until event window opens"
            );
        }
        
        if (from != address(0)) {
            salePrice[tokenId] = 0;
            seller[tokenId] = address(0);
        }
        
        return from;
    }
}
