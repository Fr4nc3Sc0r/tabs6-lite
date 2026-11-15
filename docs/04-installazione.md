# 4. Installazione e ripristino

> [!CAUTION]
> - Lo sblocco del bootloader **cancella tutti i dati** del tablet.
> - Il primo flash di software non ufficiale fa scattare il **bit Knox** in modo
>   permanente: Samsung Pass, Cartella sicura e Wallet non funzioneranno più,
>   nemmeno tornando a stock. La garanzia può decadere.
> - Questa ROM non è mai stata avviata su un dispositivo reale. Installala solo
>   se sai ripristinare il firmware stock (sezione in fondo) e hai un PC a
>   portata di mano.
> - Vale **solo per SM-P610**. Non usarla su P615 (LTE), P613, P619, P620, P625.

## Prima di iniziare

1. **Backup** di tutto ciò che ti serve (foto, documenti, dati delle app).
2. Aggiorna il tablet all'ultimo firmware ufficiale (`P610XXS7FYD1`, Android
   13) con l'aggiornamento di sistema. La ROM usa vendor e bootloader di quella
   versione: con un bootloader più vecchio il comportamento non è definito.
3. Carica la batteria oltre il 60%.
4. **Scarica subito il firmware stock completo** per il tuo CSC (4 file
   `BL_`, `AP_`, `CSC_`, `HOME_CSC_`): è la tua rete di sicurezza. Tienilo sul PC.
5. Sul PC: Odin (Windows, con i driver USB Samsung) oppure
   [samloader-rs](https://github.com/topjohnwu/samloader-rs/releases/latest)
   (Windows, Linux, macOS: è lo strumento indicato dalla wiki LineageOS), e `adb`.

## Combinazioni di tasti del Tab S6 Lite

| Modalità | Come |
|---|---|
| **Download** | Tablet spento, tieni premuti **Volume Giù + Volume Su** e collega il cavo USB al PC |
| **Recovery** | Riavvia e tieni subito premuti **Volume Su + Power** con il tablet collegato al PC via USB |
| **Spegnimento forzato** | **Volume Giù + Power** per 8–10 secondi; rilascia appena lo schermo si spegne |

(Fonte: wiki LineageOS per `gta4xlwifi`.)

## Passo 1 — Sbloccare il bootloader

1. Collega il tablet al Wi-Fi.
2. *Impostazioni → Informazioni sul tablet → Informazioni software*: tocca 7
   volte **Versione build** per attivare le Opzioni sviluppatore.
3. *Opzioni sviluppatore*: attiva **Sblocco OEM**.
   Se la voce non c'è, il tablet deve restare acceso e connesso a internet
   (anche per giorni) finché non compare: è una protezione Samsung (RMM/KG).
4. Spegni il tablet ed entra in modalità Download.
5. Nella schermata di avviso segui le istruzioni a schermo per la voce
   **Device unlock mode / Unlock bootloader** e conferma. Il tablet si azzera e
   si riavvia.
6. Completa la configurazione iniziale saltando tutto, **riconnetti il Wi-Fi**,
   riattiva le Opzioni sviluppatore e verifica che **Sblocco OEM sia ancora
   attivo** e in grigio. Se salti questo controllo, al flash successivo Odin
   può rispondere "only official released binaries are allowed to be flashed".

## Passo 2 — Installare una recovery personalizzata

La ROM si installa da una recovery che accetta zip non firmati da Samsung e
che monta le partizioni dinamiche. Opzioni:

- **Recovery di LineageOS** per `gta4xlwifi`
  (<https://download.lineageos.org/devices/gta4xlwifi>): mantenuta, affidabile,
  installa via `adb sideload`.
- **TWRP** per gta4xlwifi (thread nella sezione Tab S6 Lite di XDA): più comoda
  per i backup e per leggere i log dopo un avvio fallito.

Procedura con Odin (recovery in formato `.tar`) o samloader-rs (`.img`):

1. Tablet in modalità Download, collegato al PC.
2. *Odin*: in **Options** togli la spunta ad **Auto Reboot**; carica il `.tar`
   della recovery nello slot **AP**; **Start**.
   *samloader-rs*: `samloader flash --partition RECOVERY recovery.img --no-reboot`
3. A fine scrittura **non lasciar avviare Android**: forza lo spegnimento
   (Volume Giù + Power) e, appena lo schermo si spegne, passa a Volume Su +
   Power per entrare in recovery. Se parte il sistema stock, questo ripristina
   la recovery originale e devi ripetere il passo.

## Passo 3 — Installare la ROM

1. In recovery: **Factory reset / Format data** (formattazione completa di
   `/data`, non solo "wipe"). È obbligatorio: la ROM non usa la cifratura dei
   dati stock, e dati cifrati residui impedirebbero l'avvio.
2. Installa lo zip:
   - *Lineage Recovery*: **Apply update → Apply from ADB**, poi sul PC
     `adb sideload UN1CA_..._gta4xlwifi.zip`
   - *TWRP*: copia lo zip sul tablet (o su microSD) e **Install**.
3. Lo zip scrive: `super` (system, vendor, product, odm), `boot`, `dtbo`,
   `vbmeta`. **Non** tocca recovery, bootloader, `efs` né i dati.
4. Riavvia il sistema. **Il primo avvio può durare 10–15 minuti** (il sistema
   compila il framework sul dispositivo). Non interromperlo prima di 20 minuti.

Se non si avvia: [06-troubleshooting.md](06-troubleshooting.md). La prima cosa
da fare è recuperare i log, non riflashare alla cieca.

## Tornare al firmware stock

Funziona sempre, purché il tablet entri in modalità Download.

1. Modalità Download, Odin sul PC.
2. Carica i quattro file del firmware stock: **BL** → `BL_...`, **AP** →
   `AP_...` (attendi il caricamento, è grande), **CSC** → `CSC_...`
   (cancella i dati; `HOME_CSC_` li conserverebbe ma dopo una ROM diversa
   **va usato `CSC_`**). Lo slot **CP** resta vuoto: il P610 non ha modem.
3. **Start**. Al termine il tablet si riavvia con il firmware originale.
4. Se resta sul logo: recovery stock → *Wipe data/factory reset*.

Per ribloccare il bootloader (facoltativo): con il firmware stock installato,
modalità Download → opzione di blocco. Cancella di nuovo i dati. Il bit Knox
resta comunque scattato.

## Aggiornare a una build successiva

Stessa procedura del passo 3. Fra build della stessa versione di solito non
serve formattare i dati; se dopo l'aggiornamento il sistema non parte, la
prima prova è formattare `/data`.
