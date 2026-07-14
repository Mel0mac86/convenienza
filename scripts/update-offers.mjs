#!/usr/bin/env node
/**
 * Job notturno (GitHub Actions): cerca le offerte reali dei volantini delle
 * principali catene italiane per un paniere di prodotti popolari, tramite i
 * modelli Groq "compound" (ricerca web integrata), e salva il risultato in
 * docs/data/offers.json. La web app legge questo file: le offerte compaiono
 * all'istante, senza che ogni utente debba avere una chiave API.
 *
 * Uso: GROQ_API_KEY=gsk_... node scripts/update-offers.mjs
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const API_KEY = process.env.GROQ_API_KEY;
if (!API_KEY) {
  console.log("GROQ_API_KEY non impostata: salto l'aggiornamento (nessun errore).");
  process.exit(0);
}

const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "docs", "data", "offers.json");

/** Catene nazionali per cui i volantini sono facilmente riscontrabili online. */
const CHAINS = ["Lidl", "Eurospin", "Conad", "Coop", "Esselunga", "Carrefour", "MD", "Penny Market", "Pam", "Famila", "Despar", "In's Mercato"];

/** Paniere di prodotti popolari (i prodotti di marca hanno riscontri migliori). */
const PRODUCTS = [
  "Nutella", "Coca Cola", "Caffè Lavazza", "Pasta Barilla", "Pasta De Cecco",
  "Olio extravergine di oliva", "Latte parzialmente scremato", "Tonno Rio Mare",
  "Acqua naturale", "Birra Moretti", "Birra Ichnusa", "Parmigiano Reggiano",
  "Mozzarella", "Prosciutto cotto", "Prosciutto crudo", "Yogurt greco",
  "Biscotti Mulino Bianco", "Merendine Kinder", "Cereali Kellogg's",
  "Passata Mutti", "Riso Scotti", "Farina 00", "Zucchero", "Burro",
  "Uova", "Petto di pollo", "Banane", "Mele", "Gelato Algida",
  "Pizza surgelata", "Patatine San Carlo", "Succo di frutta",
  "Detersivo piatti", "Detersivo lavatrice Dash", "Carta igienica Scottex",
  "Bagnoschiuma", "Dentifricio Mentadent", "Crocchette per gatti", "Caffè Illy", "Fette biscottate",
];

const BATCH = 4;
const PAUSE_MS = 30_000; // tra i lotti, per stare nei limiti di token del piano gratuito
const MAX_RETRY = 6;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const normalize = (s) => s.normalize("NFD").replace(/\p{Diacritic}/gu, "").trim().toLowerCase();

function isoWeek(d = new Date()) {
  const date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const day = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  return { year: date.getUTCFullYear(), week: Math.ceil((((date - yearStart) / 86400000) + 1) / 7) };
}
function weekBounds() {
  const now = new Date(), day = (now.getDay() + 6) % 7;
  const start = new Date(now); start.setDate(now.getDate() - day); start.setHours(0, 0, 0, 0);
  const end = new Date(start); end.setDate(start.getDate() + 7);
  return { start, end };
}

async function callGroq(products) {
  const today = new Date().toLocaleDateString("it-IT", { day: "numeric", month: "long", year: "numeric" });
  const body = {
    model: "groq/compound",
    temperature: 0.2,
    max_tokens: 3000,
    messages: [
      { role: "system", content: `Sei un motore di ricerca di offerte dei supermercati fisici italiani. Cerca sul web (siti ufficiali delle catene e aggregatori di volantini come volantinofacile, promoqui, doveconviene) le promozioni ATTIVE dei volantini di questa settimana. Solo supermercati fisici: mai e-commerce o negozi online. Alla fine rispondi SOLO con JSON valido, senza testo aggiuntivo: {"offers":[{"product":"query originale","label":"nome nel volantino","chain":"Lidl","price":1.99,"previous_price":2.99,"starts_at":"2026-07-06","ends_at":"2026-07-19"}]}. "product" identico a una delle query richieste; "chain" una delle catene richieste; previous_price/starts_at/ends_at possono essere null. Includi SOLO offerte trovate davvero online, mai inventate.` },
      { role: "user", content: `Oggi è ${today}. Trova le offerte attive questa settimana nei volantini in Italia per: ${products.join(", ")}. Catene: ${CHAINS.join(", ")}.` },
    ],
  };
  for (let attempt = 1; attempt <= MAX_RETRY; attempt++) {
    const r = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const j = await r.json().catch(() => ({}));
    if (r.status === 429 || j?.error?.code === "rate_limit_exceeded") {
      const m = /in (\d+(?:\.\d+)?)s/.exec(j?.error?.message || "");
      const wait = Math.min(m ? (+m[1] + 2) * 1000 : 45_000, 90_000);
      console.log(`  rate limit (tentativo ${attempt}/${MAX_RETRY}), attendo ${Math.round(wait / 1000)}s…`);
      await sleep(wait);
      continue;
    }
    if (!r.ok) throw new Error(`HTTP ${r.status}: ${JSON.stringify(j?.error || j).slice(0, 200)}`);
    const content = j?.choices?.[0]?.message?.content;
    if (!content) throw new Error("risposta senza contenuto");
    return content;
  }
  throw new Error("rate limit persistente");
}

function parseOffers(content, requested) {
  const a = content.indexOf("{"), b = content.lastIndexOf("}");
  if (a < 0 || b <= a) return [];
  let root; try { root = JSON.parse(content.slice(a, b + 1)); } catch { return []; }
  const { start, end } = weekBounds();
  const reqMap = new Map(requested.map((p) => [normalize(p), p]));
  const chainSet = new Map(CHAINS.map((c) => [normalize(c), c]));
  return (root.offers || []).map((raw) => {
    const price = parseFloat(String(raw.price).replace(",", "."));
    if (!raw.product || !raw.label || !raw.chain || !(price > 0) || price > 500) return null;
    const norm = normalize(String(raw.product));
    let product = reqMap.get(norm);
    if (!product) for (const [k, v] of reqMap) if (norm.includes(k) || k.includes(norm)) { product = v; break; }
    if (!product) return null;
    const chain = chainSet.get(normalize(String(raw.chain))) ||
      CHAINS.find((c) => normalize(String(raw.chain)).includes(normalize(c)));
    if (!chain) return null;
    let prev = parseFloat(String(raw.previous_price ?? "").replace(",", "."));
    if (!(prev > price)) prev = null;
    const startsAt = raw.starts_at && !isNaN(new Date(raw.starts_at)) ? new Date(raw.starts_at) : start;
    let endsAt = raw.ends_at && !isNaN(new Date(raw.ends_at)) ? new Date(raw.ends_at) : end;
    if (endsAt <= new Date()) return null;
    const max = new Date(Date.now() + 60 * 86400e3);
    if (endsAt > max) endsAt = max;
    return {
      product, label: String(raw.label), chain,
      price: Math.round(price * 100) / 100,
      prev: prev ? Math.round(prev * 100) / 100 : null,
      startsAt: startsAt.toISOString(), endsAt: endsAt.toISOString(),
    };
  }).filter(Boolean);
}

async function main() {
  const { year, week } = isoWeek();
  console.log(`Aggiornamento offerte ${year}-W${week} — ${PRODUCTS.length} prodotti × ${CHAINS.length} catene`);

  // Riparte dalle offerte ancora valide già raccolte (i lotti falliti si recuperano al giro dopo).
  let previous = [];
  try {
    const old = JSON.parse(readFileSync(OUT, "utf8"));
    if (old.week === `${year}-W${week}`) previous = old.offers.filter((o) => new Date(o.endsAt) > new Date());
  } catch {}

  const found = new Map(previous.map((o) => [`${normalize(o.product)}|${o.chain}`, o]));
  let failed = 0;

  for (let i = 0; i < PRODUCTS.length; i += BATCH) {
    const batch = PRODUCTS.slice(i, i + BATCH);
    // Salta i lotti i cui prodotti hanno già offerte da un run precedente odierno?
    // No: i volantini possono aggiornarsi; il costo è accettabile una volta al giorno.
    process.stdout.write(`Lotto ${i / BATCH + 1}/${Math.ceil(PRODUCTS.length / BATCH)}: ${batch.join(", ")}\n`);
    try {
      const content = await callGroq(batch);
      const offers = parseOffers(content, batch);
      console.log(`  → ${offers.length} offerte`);
      for (const o of offers) found.set(`${normalize(o.product)}|${o.chain}`, o);
    } catch (e) {
      failed++;
      console.log(`  ✗ ${e.message}`);
      if (failed >= 5) { console.log("Troppi errori: mi fermo e salvo quanto raccolto."); break; }
      await sleep(60_000); // pausa extra dopo un fallimento: lascia svuotare la finestra dei token
    }
    if (i + BATCH < PRODUCTS.length) await sleep(PAUSE_MS);
  }

  const offers = [...found.values()].sort((a, b) => a.product.localeCompare(b.product));
  mkdirSync(dirname(OUT), { recursive: true });
  writeFileSync(OUT, JSON.stringify({
    updatedAt: new Date().toISOString(),
    week: `${year}-W${week}`,
    chains: CHAINS,
    offers,
  }, null, 1));
  console.log(`Salvate ${offers.length} offerte in docs/data/offers.json`);
}

main().catch((e) => { console.error(e); process.exit(1); });
