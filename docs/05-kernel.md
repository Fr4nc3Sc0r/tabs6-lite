# 5. Kernel

È la parte che decide se il tablet si accende. Questo documento spiega perché
il kernel stock non può funzionare, quale kernel si usa e cosa contiene.

## Perché il kernel stock non basta

Il kernel stock è un Linux 4.14 del 2020 aggiornato da Samsung fino ad Android
13. Android 16/17 dà per scontate cose che lì non esistono. Quelle note per
causare un **bootloop** (documentate dai port One UI 9 su A52s ed Exynos 990):

| Requisito di Android 17 | Sul kernel stock 4.14 | Effetto se manca |
|---|---|---|
| `netbpfload` (APEX Tethering di Google) rifiuta kernel < 5.10 (ramo 25Q4) e < 5.15 (26Q4) | Versione 4.14 | Il servizio ha `reboot_on_failure`: **riavvio continuo** con motivo `bpfloader-failed` |
| Programmi eBPF di rete/statistiche con helper e tipi di mappa recenti | Assenti | `netd` termina, niente rete, riavvii |
| Capability 38–40 (`CAP_PERFMON`, `CAP_BPF`, `CAP_CHECKPOINT_RESTORE`) | Si fermano a 37 | Il nuovo zygote nativo (`zygote_next`) legge tutte le capability 0–40: su una sconosciuta va in panic e `system_server` non parte |
| BTF (`CONFIG_DEBUG_INFO_BTF`) per il tracciamento del tempo CPU via BPF | Assente | Non fatale: statistiche batteria per-app incomplete |
| cgroup v2, PSI, uclamp, userfaultfd, binderfs, incremental-fs | In parte assenti | Da degradazioni a crash di servizi |

Compilare da zero un kernel più nuovo (5.x/6.x) per l'Exynos 9611 non è
praticabile: i driver Samsung (display, fotocamera, audio, Wi-Fi, TEE) esistono
solo per il 4.14. La strada usata da tutti i dispositivi di questa generazione
è **mantenere il 4.14 e portarci dentro ciò che serve**.

## Il kernel scelto

| | |
|---|---|
| Albero | [`Parbindar7/android_kernel_samsung_universal9611`](https://github.com/Parbindar7/android_kernel_samsung_universal9611) |
| Ramo / commit | `lineage-24.0` @ `c19ad6b2414e5c110d68ce9cccf1ba95776be317` (12/11/2026, "Add support for Android 17") |
| Versione | Linux **4.14.357** |
| Configurazione | `exynos9611-gta4xlwifi_defconfig` (esiste già nell'albero, insieme a `gta4xl`, `a51`, `m21`, `m31`...) |

Perché questo:

- deriva dai sorgenti Samsung dell'Exynos 9611 ed è usato per **LineageOS 24
  (Android 17)** sugli stessi dispositivi: i requisiti della tabella sopra sono
  già soddisfatti per un userspace Android 17;
- ha la configurazione specifica del tablet: pannello `HX83102E_GTA4XL`,
  digitalizzatore S Pen `EPEN_WACOM_W9019`, batteria `gta4xlwifi`;
- contiene già: capability fino a 40, spoof della versione per i loader BPF,
  backport eBPF, EROFS con compressione, binderfs, PSI, uclamp, incremental-fs,
  f2fs con compressione, driver sdFAT e `usb_notify` Samsung;
- le protezioni Samsung che impediscono l'avvio di sistemi modificati (`UH`/RKP)
  sono disattivate nella configurazione.

**Verificato in questo repository**: l'albero a quel commit compila con clang
18.1.3 (Ubuntu 24.04), `LLVM=1 LLVM_IAS=1`, senza errori, e produce
`Linux version 4.14.357` di circa 38 MB. La partizione `boot` è di 59 MiB:
kernel + ramdisk + DTB ci stanno; lo script lo controlla comunque a ogni build.

**Non verificato** (serve il tablet): che questo kernel, nato per LineageOS,
esponga tutto ciò che il framework **One UI** si aspetta. I sorgenti sono
quelli Samsung e i blob del vendor sono gli stessi che usa LineageOS, quindi la
base è solida, ma i punti da controllare al primo avvio sono in
[07-stato-e-roadmap.md](07-stato-e-roadmap.md).

## Cosa fa `patches/kernel/customize.sh`

1. Scarica l'albero al commit fissato (in `un1ca/out/kernel-cache/`).
2. Applica le patch in `kernel-patches/`.
3. Configura con il defconfig del tablet e fonde `config.fragment`.
4. Compila `Image` con clang.
5. Spacchetta la `boot.img` **stock**, sostituisce **solo** il kernel, e la
   ricompone con gli stessi identici parametri (header v2, offset, ramdisk,
   DTB, cmdline, livello di patch), aggiungendo in coda il marcatore
   `SEANDROIDENFORCE` che il bootloader Samsung si aspetta.
6. Verifica che sia un kernel ARM64 4.14 e che la boot entri nella partizione.

`dtbo.img` resta quello stock. La recovery non viene toccata.

## La patch inclusa

`0001-kernel-sys-configurable-BPF-loader-uname-spoof.patch`

L'albero risponde `5.10.239` alla chiamata `uname` quando a farla sono
`bpfloader`, `netbpfload` o `netd` (root): è ciò che fa passare il controllo di
versione. Il valore però è scritto nel codice. La patch lo rende regolabile
dalla **cmdline del kernel**, senza ricompilare:

| Parametro | Valori | Default |
|---|---|---|
| `uname_bpf_spoof=` | `0` spento · `1` solo `netbpfload` · `2` tutti i loader (aggiunge `uprobestats`) | `2` |
| `uname_bpf_release=` | stringa di versione riportata | `5.10.239` |

Senza parametri il comportamento è identico all'albero originale. Serve nel
caso l'APEX Tethering del firmware One UI 9 scelto applichi la soglia 5.15:

```bash
KERNEL_CMDLINE_EXTRA="uname_bpf_release=5.15.180" ./build.sh
```

Attenzione: dichiarare una versione più alta fa sì che il loader provi a
caricare anche i programmi BPF riservati a quei kernel. Se uno di quelli
"critici" usa una funzione non portata nel 4.14, il loader fallisce comunque.
Alzare la versione è quindi un tentativo, non una soluzione garantita: i casi
sono descritti in [06-troubleshooting.md](06-troubleshooting.md#bpfloader-failed).

## `config.fragment`

Modifiche di configurazione sopra il defconfig del tablet. Oggi contiene solo
il suffisso di versione (`-tabs6lite`). **Tienilo corto**: ogni riga è una
deviazione da una configurazione che avvia Android 17 su questo SoC.

Candidati da valutare solo se i log lo richiedono:

| Opzione | Quando |
|---|---|
| `CONFIG_DEBUG_INFO_BTF=y` | Statistiche CPU per-app mancanti. Richiede `pahole` (pacchetto `dwarves`) sul sistema di build e può non funzionare sul 4.14 senza ulteriori backport |
| `CONFIG_SECURITY_SELINUX_DEVELOP=y` | Già attivo: permette `androidboot.selinux=permissive` dalla cmdline per la diagnosi |

## Aggiornare il kernel

L'albero è attivo. Per provare un commit più recente:

```bash
KERNEL_COMMIT=<sha> ./tools/build_kernel.sh /tmp/k   # 1. compila?
KERNEL_COMMIT=<sha> ./build.sh                        # 2. ROM di prova
```

Se la patch non si applica più (`git apply --check` fallisce) significa che
`kernel/sys.c` è cambiato a monte: controlla se la funzione è stata integrata
o riscritta e rigenera la patch. Aggiorna il default in `customize.sh` solo
dopo aver verificato che il tablet si avvia.

## Alternative, se questo kernel non andasse

1. Stesso albero, ramo `bpf-5.15`: backport eBPF più estesi.
2. [`LineageOS/android_kernel_samsung_gta4xl`](https://github.com/LineageOS/android_kernel_samsung_gta4xl),
   ramo `lineage-23.2`: il kernel ufficiale LineageOS del tablet (Android 16).
   Più conservativo; potrebbe mancargli qualcosa per Android 17.
3. Kernel prebuilt di un port One UI 8 per A51 **non** vanno bene così come
   sono: pannello, digitalizzatore e batteria sono diversi.

In tutti i casi basta cambiare `KERNEL_REPO`/`KERNEL_COMMIT` (e, se serve,
`KERNEL_DEFCONFIG`).
