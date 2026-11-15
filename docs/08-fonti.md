# 8. Fonti

Consultate il 15 novembre 2026.

## Repository usati o analizzati

| Repository | Uso |
|---|---|
| <https://github.com/salvogiangri/UN1CA> | Sistema di build di riferimento (ramo `sixteen`, One UI 8) |
| <https://github.com/kusti420/k4_un1ca> | **Base** del port (ramo `seventeen`, One UI 9), commit `bf0d0240887c28517e08304fcf1d2bb536014f16` |
| <https://github.com/devcore94/MonsterROM> | Origine del port One UI 9 su cui si basa k4_un1ca |
| <https://github.com/xv2ice/UN1CA-A51> | Target UN1CA per Galaxy A51 (Exynos 9611), One UI 8: riferimento per il SoC e Piano B |
| <https://github.com/xv2ice/UN1CA-A51-Builder> | Esempio di build UN1CA su GitHub Actions |
| <https://github.com/Parbindar7/android_kernel_samsung_universal9611> | **Kernel**, ramo `lineage-24.0`, commit `c19ad6b2414e5c110d68ce9cccf1ba95776be317` |
| <https://github.com/LineageOS/android_kernel_samsung_gta4xl> | Kernel ufficiale LineageOS del tablet (alternativa) |
| <https://github.com/LineageOS/android_device_samsung_gta4xl-common> | Partizioni, boot image, fstab, elenco blob del vendor |
| <https://github.com/LineageOS/android_device_samsung_gta4xlwifi> | Device tree specifico Wi-Fi |
| <https://github.com/LineageOS/lineage_wiki> | Scheda hardware, combinazioni di tasti, procedura di sblocco |

## Pagine

- LineageOS, dispositivo `gta4xlwifi`: <https://wiki.lineageos.org/devices/gta4xlwifi/>
- XDA, sezione Galaxy Tab S6 Lite: <https://xdaforums.com/c/samsung-galaxy-tab-s6-lite.10969/>
- XDA, "One ui 8.5 port for SM-P615": <https://xdaforums.com/t/one-ui-8-5-port-for-sm-p615.4800162/>
- XDA, "Is there an One UI 7 port on SM-P610?": <https://xdaforums.com/t/is-there-an-one-ui-7-port-on-sm-p610.4762598/>
- XDA, UN1CA One UI 8 per Galaxy S21: <https://xdaforums.com/t/rom-16-g991b-un1ca-3-2-0-one-ui-8-0-for-galaxy-s21-5g-exynos-12-09-2026.4773332/>
- XDA, Hydrate ROM One UI 8.5 per A51: <https://xdaforums.com/t/hydrate-rom-sakura-one-ui-8-5-for-samsung-galaxy-a51-galaxy-ai-supported-s26-based-dirty-flash-supported.4790354/>
- XDA, StrataUI 8.5 per A51: <https://xdaforums.com/t/rom-beta-strataui-8-5-next-gen-one-ui-8-5-port-all-a51-models.4789065/>
- XDA, Vought Project One UI 8.5 per A51: <https://xdaforums.com/t/rom-oneui8-5-a51-vought-project-for-a51.4793024/>
- XDA, FrostSky One UI 8 per A515F: <https://xdaforums.com/t/rom-16-blaze-port-a515f-frosky-one-ui-8-galaxy-ai-a26-port-beta.4787349/>
- DroidWin, ROM per A51/F41/M31/M21: <https://droidwin.com/how-to-install-custom-roms-on-galaxy-a51-f41-m31-m31s-m21/>
- SamMobile, One UI 8 per Tab S6 Lite (solo 2024): <https://www.sammobile.com/news/galaxy-tab-s6-lite-one-ui-8-android-16/>
- SamMobile, dispositivi idonei a One UI 9: <https://www.sammobile.com/news/samsung-galaxy-phone-tablet-one-ui-9-0-android-17-eligibility/>
- SamMobile, firmware SM-P610: <https://www.sammobile.com/samsung/galaxy-tab-s6-lite/firmware/SM-P610/ILP>

## Dati letti direttamente

- Server FOTA Samsung (`fota-cloud-dn.ospserver.net/firmware/<CSC>/<modello>/version.xml`):
  ultima versione di SM-P610 (ITV), SM-S942B, e dei tablet/telefoni candidati
  come sorgente (SM-X730/X736B/X930 a One UI 9; SM-X520/X526B/X620/X710/P620/P625
  ancora a One UI 8).

## Cosa non è stato possibile consultare

- Le pagine XDA e la wiki LineageOS rispondono 403 agli strumenti automatici:
  i thread XDA sono citati dai risultati di ricerca, non letti per intero; la
  wiki è stata letta dai sorgenti su GitHub.
- Il firmware stock SM-P610 non è stato scaricato né analizzato (vedi
  [07-stato-e-roadmap.md](07-stato-e-roadmap.md)).
