# 1. Hardware del tablet e origine di ogni valore

Ogni numero usato nella configurazione ha una fonte. I valori marcati
**[VERIFY]** non sono stati letti da un dump del firmware stock (in fase di
scrittura non era disponibile): `tools/verify_target.sh` li confronta con il
firmware reale durante la build e segnala ogni differenza.

## Scheda

| | Valore | Fonte |
|---|---|---|
| Modello | SM-P610 (Wi-Fi) — il P615 è la variante LTE, codename `gta4xl` | LineageOS wiki |
| Codename | `gta4xlwifi` | LineageOS |
| SoC | Samsung Exynos 9611 (4× Cortex-A73 2,3 GHz + 4× Cortex-A53 1,7 GHz) | LineageOS wiki |
| GPU | ARM Mali-G72 MP3 | LineageOS wiki |
| RAM / storage | 4 GB / 64 o 128 GB UFS (`13520000.ufs`) | LineageOS wiki, fstab |
| Display | 10,4" TFT LCD 2000×1200, 60 Hz, densità 240, pannello HX83102E | LineageOS wiki, `BoardConfigCommon.mk`, defconfig kernel |
| S Pen | Digitalizzatore Wacom W9019 (`CONFIG_EPEN_WACOM_W9019`) | defconfig kernel |
| Fotocamere | 8 MP posteriore, 5 MP anteriore, nessun flash | LineageOS wiki |
| Audio | Due altoparlanti (AKG, Dolby Atmos), jack 3,5 mm | LineageOS wiki, blob list |
| Rete | Wi-Fi 802.11 a/b/g/n/ac, Bluetooth 5.0, GPS | LineageOS wiki |
| Assenti | Rete cellulare, NFC, lettore di impronte, motore di vibrazione, eSIM | defconfig kernel, scheda |
| Batteria | 7040 mAh | LineageOS wiki |
| TEE | TEEGRIS, Keymaster 4 | `BoardConfigCommon.mk`, blob list |
| Architettura | arm64 con userspace 32 bit secondario (HAL audio/camera anche a 32 bit) | `BoardConfigCommon.mk`, `proprietary-files.txt` |

## Software stock

| | Valore | Fonte |
|---|---|---|
| Ultimo firmware | `P610XXS7FYD1` / `P610OXM7FYD1` | Server FOTA Samsung (CSC ITV), 15/11/2026 |
| Android / One UI | 13 / 5.1.1 → SDK 33 | Server FOTA (`o="13"`) |
| Revisione bootloader | 7 (quinto carattere da destra: `...S**7**FYD1`) | nome del firmware |
| VNDK del vendor | 33 | `proprietary-files.txt` LineageOS ("VNDK v33") **[VERIFY]** |
| API di lancio | 29 (Android 10) | data di rilascio 04/2020 **[VERIFY]** |
| Kernel | Linux 4.14 | LineageOS wiki |

> **Revisione bootloader 7**: non si può tornare a firmware con revisione
> inferiore. Il firmware stock usato per la build deve essere `S7` o superiore.

## Partizioni

Fonte: `BoardConfigCommon.mk` di `android_device_samsung_gta4xl-common`
(LineageOS, ramo `lineage-23.2`), che riporta i valori del dispositivo reale.

| Partizione | Dimensione (byte) | Note |
|---|---|---|
| `boot` | 61 865 984 | Header v2, kernel `Image` non compresso, DTB dentro la boot |
| `recovery` | 71 106 560 | Il tablet ha una partizione recovery separata (non A/B) |
| `dtbo` | 8 388 608 | |
| `cache` | 209 715 200 | |
| `super` | 6 585 057 280 | **6,13 GiB**: system + vendor + product + odm |
| gruppo dinamico | 6 580 862 976 | super − 4 MiB. Nome `group_basic` **[VERIFY]** |
| `metadata` | — | Usata per la cifratura dei metadati |
| `userdata` | resto | f2fs, FBE v2 + cifratura metadati |

Parametri della boot image (stessa fonte): base `0x10000000`, kernel offset
`0x00008000`, ramdisk offset `0x01000000`, tags offset `0x00000100`, pagina
2048 byte, header versione 2. Lo script del kernel **non** li riscrive: li
legge dalla boot stock e li riusa, così non possono divergere.

Il tablet è **non A/B** e senza `vendor_boot`/`init_boot`: l'aggiornamento
avviene da recovery con uno zip, come sui Samsung di quella generazione.

## Voci di configurazione [VERIFY]

Queste voci di `overlay/target/gta4xlwifi/config.sh` descrivono come Samsung ha
configurato il framework per il tablet. Sono state impostate per deduzione
dall'hardware; il valore esatto è nel firmware stock.

| Variabile | Valore impostato | Dove lo legge `verify_target.sh` |
|---|---|---|
| `TARGET_COMMON_CONFIG_MDNIE_MODE` | `0` | `floating_feature.xml` |
| `TARGET_LCD_SUPPORT_MDNIE_HW` | `false` | `floating_feature.xml` |
| `TARGET_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS` | `3` | `floating_feature.xml` |
| `TARGET_LCD_CONFIG_HFR_MODE` | `0` | `floating_feature.xml` |
| `TARGET_AUDIO_SUPPORT_DUAL_SPEAKER` | `true` | `floating_feature.xml` |
| `TARGET_AUDIO_CONFIG_RECORDALIVE_LIB_VERSION` | `none` | `/vendor/lib*/lib_SamsungRec_*.so` |
| `TARGET_CAMERA_SUPPORT_CAMERAX_EXTENSION` | `false` | `ro.camerax.extensions.enabled` |
| `TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME` | `dvfs_policy_exynos9610_xx` | `res/raw` dell'app SDHMS stock (elenco stampato da `gen_target_from_stock.sh`) |
| `TARGET_SUPER_GROUP_NAME` | `group_basic` | `lpdump` di `super.img` (controllo bloccante) |
| `TARGET_BOARD_API_LEVEL` | `33` | `ro.vndk.version` (controllo bloccante) |

Non verificabili automaticamente (richiedono di decompilare il framework
stock, vedi commenti in `gen_config_file.sh` della base):
`TARGET_FINGERPRINT_CONFIG_SENSOR`, `TARGET_LCD_CONFIG_COLOR_WEAKNESS_SOLUTION`,
`TARGET_CAMERA_SUPPORT_MASS_APP_FLAVOR`, `TARGET_CAMERA_SUPPORT_SDK_SERVICE`,
`TARGET_BLUETOOTH_SUPPORT_A2DPSINK_PROFILE`,
`TARGET_RIL_SIM_CONFIG_MULTISIM_TRAYCOUNT`. Sono elencate in
[07-stato-e-roadmap.md](07-stato-e-roadmap.md) come attività aperte.

## File presi dal firmware stock (non scritti a mano)

`tools/gen_target_from_stock.sh` li copia nel target a ogni build:

| File nel target | Origine nel firmware stock |
|---|---|
| `vintf/compatibility_matrix.device.xml` | `/system/etc/vintf/` |
| `camera/camera-feature.xml` | `/system/cameradata/` |
| `overlay/` (luminosità, profilo energetico, display) | `res/` di `framework-res__*__auto_generated_rro_product.apk` in `/product/overlay` |
| `dvfs/<policy>.xml` | `res/raw/` dell'app `SamsungDeviceHealthManagerService` |

Inoltre la base fonde automaticamente il `floating_feature.xml` stock del
tablet in quello di One UI 9: le funzioni dichiarate dal tablet (S Pen, layout
tablet, altoparlanti, display) mantengono il valore del tablet.
