const WALLETS = [
  { name: "Organizer", addr: "0x71C7656EC7ab88b098defB751B7401B5f6d8976A", balance: 1.50, isOwner: true },
  { name: "Fan A",     addr: "0xA3B1cD4eF5G6H7I8J9K0L1M2N3O4P5Q6R7S8T9U0", balance: 2.00, isOwner: false },
  { name: "Fan B",     addr: "0xE5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U1V2W3X4", balance: 1.20, isOwner: false },
];

const EVENT_CONFIG = {
  "FIFA World Cup Final 2026": { faceValue: 0.05, maxResale: 0.06, icon: "⚽" },
  "Pokemon TCG Championship":  { faceValue: 0.01, maxResale: 0.012, icon: "🎴" },
};

let currentWallet = 0;
let nextTokenId = 1;
let tickets = [];
let listings = {};

try {
  const saved = localStorage.getItem('nft_ticketing_state');
  if (saved) {
    const data = JSON.parse(saved);
    tickets = data.tickets || [];
    listings = data.listings || {};
    nextTokenId = data.nextTokenId || 1;
    WALLETS[0].balance = data.balances?.[0] ?? 1.50;
    WALLETS[1].balance = data.balances?.[1] ?? 2.00;
    WALLETS[2].balance = data.balances?.[2] ?? 1.20;
  }
} catch(e) {}

function saveState() {
  localStorage.setItem('nft_ticketing_state', JSON.stringify({
    tickets, listings, nextTokenId,
    balances: WALLETS.map(w => w.balance)
  }));
}

function shortAddr(addr) {
  return addr.slice(0, 6) + "..." + addr.slice(-4);
}

function toast(msg, type) {
  const el = document.getElementById("toast");
  el.textContent = msg;
  el.className = "toast " + type;
  requestAnimationFrame(() => el.classList.add("show"));
  setTimeout(() => el.classList.remove("show"), 4000);
}

function updateWalletUI() {
  const w = WALLETS[currentWallet];
  const chip = document.getElementById("walletChip");
  const label = document.getElementById("walletLabel");

  chip.classList.add("connected");
  label.innerHTML = '<span class="addr">' + w.name + '</span> — ' + shortAddr(w.addr);

  document.getElementById("balance").textContent = w.balance.toFixed(3) + " ETH";
  document.getElementById("role").textContent = w.isOwner ? "Organizer" : "Fan";
  document.getElementById("role").style.color = w.isOwner ? "#ff4d9e" : "#00d4ff";

  document.getElementById("organizerPanel").style.display = w.isOwner ? "block" : "none";

  document.querySelectorAll(".sw").forEach((el, i) => {
    el.classList.toggle("active", i === currentWallet);
  });

  renderMyTickets();
  renderMarketplace();
}

function toggleWallet() {
  currentWallet = (currentWallet + 1) % WALLETS.length;
  updateWalletUI();
  toast("Switched to " + WALLETS[currentWallet].name, "ok");
}

function switchWallet(idx) {
  currentWallet = idx;
  updateWalletUI();
  toast("Switched to " + WALLETS[currentWallet].name, "ok");
}

function mintTicket() {
  const w = WALLETS[currentWallet];
  if (!w.isOwner) { toast("Only Organizer can mint tickets", "err"); return; }

  const eventName = document.getElementById("mintEvent").value;
  const toAddr = document.getElementById("mintTo").value;
  const cfg = EVENT_CONFIG[eventName];

  let toIdx = WALLETS.findIndex(x => x.addr === toAddr);
  if (toIdx === -1) { toast("Invalid recipient", "err"); return; }

  const tokenId = nextTokenId++;
  const now = Date.now();
  const unlockAt = now + 5 * 60 * 1000;

  tickets.push({
    tokenId,
    eventName,
    faceValue: cfg.faceValue,
    maxResalePrice: cfg.maxResalePrice,
    transferOpensAt: unlockAt,
    isRedeemed: false,
    owner: toAddr,
    icon: cfg.icon,
    createdAt: now,
  });

  saveState();
  toast("Ticket #" + tokenId + " minted for " + WALLETS[toIdx].name + "!", "ok");
  renderMyTickets();
  renderMarketplace();
}

function renderMyTickets() {
  const w = WALLETS[currentWallet];
  const mine = tickets.filter(t => t.owner === w.addr);
  const container = document.getElementById("myTickets");

  if (mine.length === 0) {
    container.innerHTML = '<div class="empty">' + w.name + " doesn't own any tickets yet</div>";
    return;
  }

  let html = '<div class="ticket-list">';
  for (const t of mine) {
    const now = Date.now();
    const isLocked = now < t.transferOpensAt;
    const isListed = listings[t.tokenId];
    const isRedeemed = t.isRedeemed;

    let tagClass = isRedeemed ? "redeemed" : (isLocked ? "locked" : "open");
    let tagText = isRedeemed ? "REDEEMED" : (isLocked ? "LOCKED (Soulbound)" : "TRANSFERABLE");
    if (isListed) { tagClass = "sale"; tagText = "FOR SALE"; }

    html += '<div class="tkt">' +
      '<div class="id">Token #' + t.tokenId + '</div>' +
      '<div class="name">' + t.icon + ' ' + t.eventName + '</div>' +
      '<div class="meta">Face: ' + t.faceValue + ' ETH • Max Resale: ' + t.maxResalePrice + ' ETH</div>' +
      '<div class="meta">' + (isLocked ? "Unlocks in " + Math.ceil((t.transferOpensAt - now)/60000) + " min" : "Transfer window open") + '</div>' +
      '<span class="tag ' + tagClass + '">' + tagText + '</span>';

    if (!isRedeemed && !isListed) {
      html += '<div style="margin-top:12px;"><div class="row2">' +
        '<input type="number" step="0.001" id="price-' + t.tokenId + '" placeholder="Price in ETH" ' + (isLocked ? 'disabled' : '') + '>' +
        '<button ' + (isLocked ? 'disabled' : '') + ' onclick="listTicket(' + t.tokenId + ')">List for Sale</button>' +
        '</div></div>';
    }

    if (isListed) {
      html += '<div style="margin-top:10px;color:#8a7af0;font-size:13px;">' +
        'Listed at ' + listings[t.tokenId].price + ' ETH' +
        '<button class="small pink" style="margin-left:8px;" onclick="cancelListing(' + t.tokenId + ')">Cancel</button>' +
        '</div>';
    }

    html += '</div>';
  }
  html += '</div>';
  container.innerHTML = html;
}

function listTicket(tokenId) {
  const input = document.getElementById("price-" + tokenId);
  const price = parseFloat(input.value);
  const w = WALLETS[currentWallet];

  if (!price || price <= 0) { toast("Enter a valid price", "err"); return; }

  const t = tickets.find(x => x.tokenId === tokenId);
  if (!t) return;

  if (t.owner !== w.addr) { toast("You don't own this ticket", "err"); return; }
  if (Date.now() < t.transferOpensAt) { toast("Transfer window is locked", "err"); return; }

  if (price > t.maxResalePrice) {
    toast("ANTI-SCALPING BLOCKED! Max allowed: " + t.maxResalePrice + " ETH. You tried: " + price + " ETH", "err");
    return;
  }

  listings[tokenId] = { price, seller: w.addr };
  saveState();
  toast("Ticket #" + tokenId + " listed at " + price + " ETH!", "ok");
  renderMyTickets();
  renderMarketplace();
}

function cancelListing(tokenId) {
  const w = WALLETS[currentWallet];
  if (!listings[tokenId] || listings[tokenId].seller !== w.addr) {
    toast("You didn't list this ticket", "err"); return;
  }
  delete listings[tokenId];
  saveState();
  toast("Listing cancelled", "ok");
  renderMyTickets();
  renderMarketplace();
}

function renderMarketplace() {
  const w = WALLETS[currentWallet];
  const active = Object.keys(listings).map(Number);
  const container = document.getElementById("marketplace");

  if (active.length === 0) {
    container.innerHTML = '<div class="empty">No active listings</div>';
    return;
  }

  let html = '';
  for (const id of active) {
    const t = tickets.find(x => x.tokenId === id);
    const l = listings[id];
    if (!t || !l) continue;

    const isMine = l.seller === w.addr;
    const sellerName = WALLETS.find(x => x.addr === l.seller)?.name || "Unknown";

    html += '<div class="mkt-item">' +
      '<div class="info">' +
        '<div class="nm">' + t.icon + ' ' + t.eventName + '</div>' +
        '<div class="sl">Token #' + id + ' • Seller: ' + sellerName + ' (' + shortAddr(l.seller) + ')</div>' +
      '</div>' +
      '<div class="price">' + l.price + ' ETH</div>' +
      (isMine ? '<span style="color:#8a7af0;font-size:12px;font-weight:700;">Your Listing</span>' : '<button onclick="buyTicket(' + id + ')">Buy Now</button>') +
      '</div>';
  }
  container.innerHTML = html;
}

function buyTicket(tokenId) {
  const w = WALLETS[currentWallet];
  const l = listings[tokenId];
  const t = tickets.find(x => x.tokenId === tokenId);

  if (!l || !t) { toast("Listing not found", "err"); return; }
  if (l.seller === w.addr) { toast("You can't buy your own ticket", "err"); return; }
  if (w.balance < l.price) { toast("Insufficient ETH balance", "err"); return; }

  const sellerIdx = WALLETS.findIndex(x => x.addr === l.seller);
  if (sellerIdx !== -1) WALLETS[sellerIdx].balance += l.price;
  w.balance -= l.price;

  t.owner = w.addr;
  delete listings[tokenId];

  saveState();
  toast("Bought Ticket #" + tokenId + " for " + l.price + " ETH!", "ok");
  updateWalletUI();
}

function redeemTicket() {
  const w = WALLETS[currentWallet];
  if (!w.isOwner) { toast("Only Organizer can redeem tickets", "err"); return; }

  const id = parseInt(document.getElementById("redeemId").value);
  if (isNaN(id)) { toast("Enter a valid ticket ID", "err"); return; }

  const t = tickets.find(x => x.tokenId === id);
  if (!t) { toast("Ticket not found", "err"); return; }
  if (t.isRedeemed) { toast("Ticket already redeemed", "err"); return; }

  t.isRedeemed = true;
  saveState();
  toast("Ticket #" + id + " redeemed at gate! Entry granted.", "ok");
  document.getElementById("redeemId").value = "";
  renderMyTickets();
}

updateWalletUI();

setInterval(() => {
  if (tickets.length > 0) renderMyTickets();
}, 10000);
