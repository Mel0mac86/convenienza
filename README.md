# Convenienza 🛒

Assistente intelligente per la spesa: monitora i prodotti che vuoi acquistare e ti
avvisa **solo** quando uno di essi è realmente in offerta in un **supermercato fisico
vicino alla tua posizione**. Nessun e-commerce, nessun marketplace, nessun negozio
online: solo la GDO del territorio.

App nativa per **iOS 17+**, scritta in **SwiftUI** con **SwiftData**, MapKit,
CoreLocation, UserNotifications, BackgroundTasks e Swift Charts.

## Funzionalità

- **Registrazione e accesso** — account locale con password salata e hashata (SHA-256),
  con interfaccia async pronta per essere collegata a un backend remoto.
- **Geolocalizzazione con consenso** — la posizione viene richiesta esplicitamente e
  usata solo per trovare i supermercati fisici in zona.
- **Rilevamento automatico dei supermercati** entro un raggio configurabile
  (5 / 10 / 20 / 30 km) tramite MapKit, con riconoscimento delle principali catene
  italiane (Coop, Conad, Esselunga, Lidl, Eurospin, Carrefour, MD, Penny, …).
- **Ricerca prodotti con salvataggio automatico** — ogni prodotto cercato entra nella
  lista personale e viene monitorato nel tempo.
- **Controllo periodico delle offerte** — in foreground (apertura, cambio posizione,
  pull-to-refresh) e in background tramite `BGAppRefreshTask`.
- **Confronto prezzi tra supermercati vicini** e **storico prezzi** per ogni prodotto
  (grafico Swift Charts, per catena).
- **Notifiche push locali** quando un prodotto monitorato entra in promozione, con:
  nome prodotto, prezzo in offerta, prezzo precedente, sconto %, nome del supermercato,
  distanza dal punto vendita e data di scadenza della promozione. Una sola notifica
  per offerta, mai duplicata.
- **Aggiornamento automatico al cambio di posizione/città** — spostamenti significativi
  fanno ripartire il rilevamento dei supermercati e il controllo delle offerte.
- **Dashboard** con prodotti monitorati, offerte attive, offerte in scadenza,
  supermercati vicini e accesso allo storico prezzi.
- **Filtri offerte** per distanza, supermercato, categoria, percentuale di sconto e
  prezzo massimo, con ordinamento per distanza / sconto / prezzo / scadenza.

## Struttura del progetto

```
Convenienza/
├── App/            # Entry point, stato globale, impostazioni
├── Models/         # SwiftData (@Model) e modelli di dominio
├── Services/       # Posizione, supermercati, offerte, notifiche, background, auth
└── Views/          # SwiftUI: Auth, Dashboard, Search, Offers, Products, Settings
```

### Architettura

- **`MonitoringEngine`** è il cuore dell'app: prodotti monitorati → supermercati in
  zona → offerte per catena → nuovi record + storico prezzi → notifiche.
- **`OfferProvider`** è il protocollo che astrae la sorgente dei prezzi.
  - **`GroqOfferProvider`** (produzione) — usa i modelli **Groq `groq/compound`**
    con ricerca web integrata per trovare le offerte **realmente pubblicate** nei
    volantini della GDO italiana (siti delle catene e aggregatori come PromoQui,
    DoveConviene, VolantinoFacile) e le restituisce in JSON strutturato e validato.
    Nessun prezzo inventato: se non c'è riscontro online, il prodotto non compare.
    Include cache per settimana promozionale (TTL 6 h), richieste a piccoli lotti e
    gestione automatica del rate limit del piano gratuito (HTTP 429 + retry).
  - **`SimulatedOfferProvider`** — solo modalità demo, disattivata di default.
- **`SupermarketService`** usa `MKLocalSearch` con filtro `foodMarket`: per requisito
  vengono considerati **solo punti vendita fisici** sul territorio.

### Configurazione dei prezzi reali

1. Crea una chiave API gratuita su [console.groq.com](https://console.groq.com).
2. Nell'app: **Profilo → Sorgente prezzi reali** → incolla la chiave → *Salva*.

La chiave è salvata **solo nel Keychain del dispositivo**: non finisce mai nel
repository né in UserDefaults.

## 📱 Versione web (senza Mac: si installa da Safari)

In `docs/` c'è una versione **web app (PWA)** completa di Convenienza che gira
interamente nel browser dell'iPhone e si installa dalla condivisione di Safari
(**Aggiungi alla schermata Home**). Non servono Mac, Xcode o App Store.

- Posizione via browser (con consenso), supermercati fisici reali da
  **OpenStreetMap** (Overpass API), città via Nominatim.
- Offerte reali via **Groq compound** (ricerca web), stessa logica dell'app
  nativa: cache settimanale, lotti piccoli, gestione del rate limit.
- Tutti i dati (lista prodotti, offerte, storico, chiave API) restano nel
  browser del dispositivo.

**Uso immediato** (subito, senza configurare nulla):
apri in Safari `https://raw.githack.com/Mel0mac86/convenienza/claude/ios-grocery-tracker-jm65vq/docs/index.html`

**URL stabile con GitHub Pages** (consigliato): Settings → Pages →
*Deploy from a branch* → scegli il branch e la cartella `/docs` → Save.
L'app sarà su `https://mel0mac86.github.io/convenienza/`.

Limite della versione web: iOS non consente notifiche push web senza un server
di push, quindi il controllo offerte avviene all'apertura dell'app (e ogni 30
minuti mentre è aperta), con avvisi in-app. Le notifiche push vere restano una
funzionalità dell'app nativa.

## Requisiti e build (app nativa)

- Xcode 15+ (iOS 17 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) per generare il progetto

```bash
brew install xcodegen
xcodegen generate
open Convenienza.xcodeproj
```

Seleziona il tuo team di firma in *Signing & Capabilities*, quindi esegui su
simulatore o dispositivo. Su simulatore imposta una posizione
(*Features → Location → Custom Location*, es. Roma 41.9028, 12.4964) per vedere i
supermercati reali della zona.

### Note sul background refresh

iOS decide autonomamente quando eseguire i `BGAppRefreshTask` (tipicamente in base
all'uso dell'app e allo stato della batteria). Per testare il task in Xcode:
metti l'app in background, poi in LLDB:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"it.convenienza.app.refresh"]
```

## Privacy

- La posizione è usata **solo previo consenso** e solo per trovare supermercati vicini.
- Le ricerche sono salvate **solo sul dispositivo** (SwiftData).
- Le password non vengono mai salvate in chiaro.
