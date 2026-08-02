// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NFTTicket
 * @notice Simple anti-scalping NFT ticket system
 * @dev Tickets are ERC-721 NFTs with price caps and transfer locks
 */
contract NFTTicket is ERC721, Ownable {

    struct Ticket {
        string eventName;
        uint256 faceValue;
        uint256 maxResalePrice;
        uint256 transferOpensAt;
        bool isRedeemed;
    }

    // ticket ID => ticket details
    mapping(uint256 => Ticket) public tickets;

    // ticket ID => (price, seller) for marketplace
    mapping(uint256 => uint256) public salePrice;
    mapping(uint256 => address) public seller;

    uint256 public nextTokenId;

    // Events for frontend tracking
    event TicketMinted(uint256 indexed tokenId, string eventName, address indexed to);
    event TicketListed(uint256 indexed tokenId, uint256 price);
    event TicketSold(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event TicketRedeemed(uint256 indexed tokenId);
    event ListingCancelled(uint256 indexed tokenId);
    event MaxResalePriceUpdated(uint256 indexed tokenId, uint256 newPrice);

    constructor() ERC721("NFTTicket", "TICKET") Ownable(msg.sender) {}

    // Only organizer can mint tickets
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

    // Owner lists ticket for resale
    // ANTI-SCALPING: price must be <= maxResalePrice
    function listTicket(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(block.timestamp >= tickets[tokenId].transferOpensAt, "Locked: soulbound");
        require(price <= tickets[tokenId].maxResalePrice, "Anti-scalping: price too high");
        require(price > 0, "Price must be > 0");

        salePrice[tokenId] = price;
        seller[tokenId] = msg.sender;

        emit TicketListed(tokenId, price);
    }

    // Anyone can buy a listed ticket
    function buyTicket(uint256 tokenId) external payable {
        uint256 price = salePrice[tokenId];
        address oldOwner = seller[tokenId];

        require(price > 0, "Not for sale");
        require(msg.value >= price, "Send exact price");

        // Clear listing before transfer
        salePrice[tokenId] = 0;
        seller[tokenId] = address(0);

        // Transfer NFT and pay seller
        _transfer(oldOwner, msg.sender, tokenId);
        payable(oldOwner).transfer(price);

        // Refund extra ETH
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        emit TicketSold(tokenId, msg.sender, price);
    }

    // Cancel an active listing
    function cancelListing(uint256 tokenId) external {
        require(seller[tokenId] == msg.sender, "Not the seller");

        salePrice[tokenId] = 0;
        seller[tokenId] = address(0);

        emit ListingCancelled(tokenId);
    }

    // Organizer redeems ticket at venue gate
    function redeemTicket(uint256 tokenId) external onlyOwner {
        require(!tickets[tokenId].isRedeemed, "Already used");
        tickets[tokenId].isRedeemed = true;
        emit TicketRedeemed(tokenId);
    }

    // Update max resale price for a ticket (e.g., if demand changes)
    function updateMaxResalePrice(uint256 tokenId, uint256 newPrice) external onlyOwner {
        require(_exists(tokenId), "Ticket does not exist");
        require(newPrice >= tickets[tokenId].faceValue, "Price below face value");
        tickets[tokenId].maxResalePrice = newPrice;
        emit MaxResalePriceUpdated(tokenId, newPrice);
    }

    // Extend transfer lock (e.g., event postponed)
    function extendTransferLock(uint256 tokenId, uint256 newUnlockTime) external onlyOwner {
        require(_exists(tokenId), "Ticket does not exist");
        require(newUnlockTime > tickets[tokenId].transferOpensAt, "Must extend");
        tickets[tokenId].transferOpensAt = newUnlockTime;
    }

    // Check if a ticket is valid for entry
    function isValidForEntry(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId) && !tickets[tokenId].isRedeemed;
    }

    // Get total number of tickets minted
    function totalSupply() external view returns (uint256) {
        return nextTokenId;
    }

    // Get all token IDs owned by an address
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

    // Get all active marketplace listings
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

    // Withdraw stuck ETH (safety function)
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds");
        payable(owner()).transfer(balance);
    }

    // Block transfers before unlock time (soulbound tickets)
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = super._update(to, tokenId, auth);

        // If normal transfer (not mint or burn), check unlock time
        if (from != address(0) && to != address(0)) {
            require(
                block.timestamp >= tickets[tokenId].transferOpensAt,
                "Transfer locked until event window opens"
            );
        }

        // Clear any active listing on transfer
        if (from != address(0)) {
            salePrice[tokenId] = 0;
            seller[tokenId] = address(0);
        }

        return from;
    }

    // Helper: check if token exists
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId < nextTokenId;
    }
}
