# tabs6-lite — One UI 9 per Galaxy Tab S6 Lite Wi-Fi 2020 (SM-P610)

Port di **One UI 9 (Android 17)** per il Samsung Galaxy Tab S6 Lite Wi-Fi 2020
(`SM-P610`, codename `gta4xlwifi`, Exynos 9611), costruito come fanno le ROM
[UN1CA](https://github.com/salvogiangri/UN1CA): si parte dal firmware ufficiale
Samsung di un dispositivo recente (Galaxy S26, One UI 9), lo si combina con
vendor e driver originali del tablet e si applicano le patch necessarie.

> [!WARNING]
> **Stato: bring-up, mai avviato su un dispositivo reale.**
> In questo repository tutto ciò che si poteva verificare senza il tablet e
> senza il suo firmware è stato verificato (il kernel compila, le patch si
> applicano, gli script sono stati provati). Il primo avvio su hardware vero
> non è ancora stato fatto: aspettati più cicli di build → flash → log →
> correzione prima di avere un sistema usabile. Leggi
> [docs/07-stato-e-roadmap.md](docs/07-stato-e-roadmap.md) prima di tutto.

## Come è fatto

Questo repository **non contiene** il sistema di build né file Samsung: contiene
solo ciò che è specifico del tablet, applicato sopra una base fissata a un
commit preciso.

| Percorso | Contenuto |
|---|---|
| `setup.sh` | Scarica la base (fork One UI 9 di UN1CA) e ci copia sopra `overlay/` |
| `build.sh` | Build completa: firmware → verifica → ROM → zip flashabile |
| `overlay/platform/exynos9611/` | Piattaforma Exynos 9611: configurazione e **kernel** |
| `overlay/target/gta4xlwifi/` | Il tablet: partizioni, funzioni, modalità tablet, installer |
| `tools/` | Generazione dei file dal firmware stock, verifica, report dimensioni |
| `.github/workflows/` | Build su GitHub Actions (ROM completa e solo kernel) |
| `docs/` | Documentazione completa |

## Avvio rapido

```bash
export TABS6_SERIAL=R...........   # numero di serie del TUO tablet (11 caratteri)
./build.sh --probe-only            # scarica i firmware e verifica la configurazione
./build.sh                         # build completa, zip in un1ca/out/
```

Oppure da GitHub: *Actions → Build ROM (gta4xlwifi) → Run workflow* (serve il
secret `TABS6_SERIAL`, vedi [docs/03-build.md](docs/03-build.md)).

## Documentazione

1. [Fattibilità e ricerca](docs/00-fattibilita.md) — si può fare? cosa esiste già?
2. [Hardware del tablet](docs/01-hardware.md) — ogni valore usato e da dove viene
3. [Architettura del port](docs/02-architettura.md) — come si compone la ROM
4. [Build](docs/03-build.md) — in locale e su GitHub Actions
5. [Installazione e ripristino](docs/04-installazione.md) — flash e ritorno a stock
6. [Kernel](docs/05-kernel.md) — perché serve un kernel nuovo e cosa contiene
7. [Risoluzione dei problemi](docs/06-troubleshooting.md) — per fase di avvio
8. [Stato e roadmap](docs/07-stato-e-roadmap.md) — cosa è verificato, cosa no
9. [Fonti](docs/08-fonti.md)

## Licenza e crediti

Script e configurazioni di questo repository: GPL-3.0-or-later, come la base.
Il sistema di build è di [UN1CA](https://github.com/salvogiangri/UN1CA)
(salvogiangri e contributori); il port One UI 9 su cui ci si appoggia è di
[MonsterROM](https://github.com/devcore94/MonsterROM) e
[k4_un1ca](https://github.com/kusti420/k4_un1ca); il kernel è l'albero
comunitario [universal9611](https://github.com/Parbindar7/android_kernel_samsung_universal9611);
i dati del dispositivo vengono dai device tree di [LineageOS](https://github.com/LineageOS/android_device_samsung_gta4xl-common).
Questo progetto non è affiliato a nessuno di loro né a Samsung.
