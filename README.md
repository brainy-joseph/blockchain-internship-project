# NFT Ticketing & Anti-Scalping Protocol

**Live Demo:** [brainy-joseph.github.io/blockchain-internship-project](https://brainy-joseph.github.io/blockchain-internship-project)

A blockchain-based ticketing system that stops scalpers and eliminates fraud using Ethereum smart contracts.

## The Problem

- **Scalping:** Bots buy tickets and resell at 5-50x price
- **Fraud:** Counterfeit tickets leave fans stranded
- **Lost Royalties:** Creators get $0 from resales

**Total loss: ~$27 billion/year**

## The Solution

Tokenize tickets as programmable NFTs with rules enforced by smart contracts:

| Feature | How It Works |
|---------|-------------|
| Price Ceiling | Max resale price hard-coded (e.g. 120% of face value). Cannot be bypassed. |
| Soulbound Lock | Tickets are locked until 48-72 hours before the event. No early flipping. |
| On-Chain History | Every owner and price recorded permanently. No counterfeits. |
| Auto Royalties | Revenue splits automatically on every resale. |

## How to Use the Demo

1. Open the [live demo](https://brainy-joseph.github.io/blockchain-internship-project)
2. **Mint** a ticket as Organizer
3. **Try to scalp** as Fan A (list above the cap) → **BLOCKED**
4. **List fairly** within the cap → appears in Marketplace
5. **Buy** as Fan B
6. **Redeem** as Organizer at the gate
7. Check Fan B — ticket shows **REDEEMED**

## Tech Stack

- **Blockchain:** Ethereum (Sepolia testnet)
- **Smart Contract:** Solidity + OpenZeppelin ERC-721
- **Frontend:** HTML, CSS, JavaScript
- **Hosting:** GitHub Pages

## Project Files

## Files

- `index.html` — Landing page
- `frontend/index.html` — Demo app
- `frontend/style.css` — Styles
- `frontend/script.js` — App logic
- `backend/contracts/NFTTicket.sol` — Smart contract



