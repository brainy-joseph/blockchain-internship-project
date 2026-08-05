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

    event TicketMinted(uint256 indexed tokenId, string eventName, address indexed to);
    event TicketListed(uint256 indexed tokenId, uint256 price);
    event TicketSold(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event TicketRedeemed(uint256 indexed tokenId);
    event ListingCancelled(uint256 indexed tokenId);
    event MaxResalePriceUpdated(uint256 indexed tokenId, uint256 newPrice);

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
        emit TicketMinted(tokenId, eventName, to);
    }

    function listTicket(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(block.timestamp >= tickets[tokenId].transferOpensAt, "Locked: soulbound");
        require(price <= tickets[tokenId].maxResalePrice, "Anti-scalping: price too high");
        require(price > 0, "Price must be > 0");

        salePrice[tokenId] = price;
        seller[tokenId] = msg.sender;

        emit TicketListed(tokenId, price);
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

        emit TicketSold(tokenId, msg.sender, price);
    }

    function cancelListing(uint256 tokenId) external {
        require(seller[tokenId] == msg.sender, "Not the seller");

        salePrice[tokenId] = 0;
        seller[tokenId] = address(0);

        emit ListingCancelled(tokenId);
    }

    function redeemTicket(uint256 tokenId) external onlyOwner {
        require(!tickets[tokenId].isRedeemed, "Already used");
        tickets[tokenId].isRedeemed = true;
        emit TicketRedeemed(tokenId);
    }

    function updateMaxResalePrice(uint256 tokenId, uint256 newPrice) external onlyOwner {
        require(_exists(tokenId), "Ticket does not exist");
        require(newPrice >= tickets[tokenId].faceValue, "Price below face value");
        tickets[tokenId].maxResalePrice = newPrice;
        emit MaxResalePriceUpdated(tokenId, newPrice);
    }

    function extendTransferLock(uint256 tokenId, uint256 newUnlockTime) external onlyOwner {
        require(_exists(tokenId), "Ticket does not exist");
        require(newUnlockTime > tickets[tokenId].transferOpensAt, "Must extend");
        tickets[tokenId].transferOpensAt = newUnlockTime;
    }

    function isValidForEntry(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId) && !tickets[tokenId].isRedeemed;
    }

    function totalSupply() external view returns (uint256) {
        return nextTokenId;
    }

    function getTokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory result = new uint256[](balance);
        uint256 counter = 0;

        for (uint256 i = 0; i < nextTokenId; i++) {
            if (ownerOf(i) == owner) {
                result[counter] = i;
                counter++;
            }
        }
        return result;
    }

    function getActiveListings() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextTokenId; i++) {
            if (salePrice[i] > 0) count++;
        }

        uint256[] memory result = new uint256[](count);
        uint256 counter = 0;
        for (uint256 i = 0; i < nextTokenId; i++) {
            if (salePrice[i] > 0) {
                result[counter] = i;
                counter++;
            }
        }
        return result;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds");
        payable(owner()).transfer(balance);
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

    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId < nextTokenId;
    }
}
