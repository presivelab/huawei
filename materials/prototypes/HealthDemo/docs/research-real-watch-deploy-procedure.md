RAPORT: uruchomienie debugowej aplikacji ArkTS na prawdziwym zegarku Huawei z Windows (DevEco 6.1.1, API 24). Nic nie zapisano, nic nie zainstalowano.

Skróty: [D] = oficjalny dokument Huawei, pobrany z backendu `svc-drcn.developer.huawei.com/.../documentPortal/getDocumentById` (POST z JSON `{"objectId":"<id>","version":"","language":"en"}`; GET zwraca 405). [F] = wpis na forum Huawei zrewidowany na dev.to (pisał go użytkownik, nie Huawei). [P] = fragment mojej analizy, a nie cytat ze źródła.

## 0. Najważniejsze wnioski (przed krokami)

- Zegarki "wearable" (pełny ArkTS) obsługują **tylko debugowanie bezprzewodowe**. USB nie wchodzi w grę. [D ide-run-device: "Wearables (excluding lite wearables) support only wireless debugging."]
- Niepodpisany HAP nie zadziała na prawdziwym urządzeniu. [D agc-harmonyapp-debugharmonyapp: "Only signed HAPs can be installed on devices for running."] Dokładnego komunikatu błędu dla *całkowicie niepodpisanego* HAP-a nie znalazłem (nie potwierdzono). Znany jest błąd dla *złego typu* podpisu: `code:9568257 error: fail to verify pkcs7 file`. Naprawa: zaznaczyć "Support HarmonyOS" przy podpisywaniu. [D faqs-app-debugging-6-V5]
- **Oba uprawnienia, `READ_HEALTH_DATA` i `ACTIVITY_MOTION`, mają poziom "normal" i tryb "user_grant", z obsługą "wearable"**. [D permissions-for-all-user] Nie są to uprawnienia ACL ani ograniczone. Wniosek [P]: wystarczy automatyczny podpis, bez profilu ACL z AppGallery Connect. Dokument automatycznego podpisu mówi, że weryfikacja ACL dotyczy tylko uprawnień dopisanych do listy ACL.
- Dla aplikacji NIEpowiązanej z zarejestrowaną aplikacją AGC automatyczny podpis nie ma w dokumentacji ograniczenia regionalnego. Ograniczenie "tylko Chiny kontynentalne do 6.1.1 Beta1" dotyczy wariantu *Associate with registered application*. [D ide-signing-auto]
- Tryb CN w DevEco a podpis: nie znalazłem żadnego źródła, które mówi, że ustawienie regionu DevEco blokuje podpis konta spoza Chin (nie potwierdzono, ani że blokuje, ani że nie). Dokumentacja wymaga tylko zalogowania i zsynchronizowanego czasu (patrz krok 4).
- Nie ma źródła potwierdzającego, że HEART_RATE, PEDOMETER czy WEAR_DETECTION działają dla aplikacji trzecich na WATCH 5 w każdych warunkach. Jest jedno forumowe potwierdzenie dla HEART_RATE na WATCH 5 (krok 6).

## 1. Które zegarki i jakie warunki

Potwierdzone:
- HUAWEI WATCH 5 jest celem w oficjalnych przewodnikach: "Tested on the Huawei Watch 5 device. It works as expected" [F, heart rate z Sensor Kit], a także w przewodniku Oniro dla WATCH 5 na OpenHarmony 5.1.0 Release+, API 18 [oniroproject codelab wearable/health]. Zegarek ma HarmonyOS 5.1, a HarmonyOS 6 ma publiczną betę (wyniki wyszukiwania huaweicentral).
- Wymagana wersja systemu urządzenia w dokumencie uruchamiania: "HarmonyOS NEXT Developer Beta1 or later" [D ide-run-device]. To ogólna reguła dla wszystkich urządzeń, nie tabela modeli zegarków.
- Rozróżnienie pojęć: "wearable" (pełny ArkTS, wireless) kontra "lite wearable" i "sports watch" (inne ścieżki, np. Huawei DevEco Assistant i Wear Engine) [D ide-run-device; D agc-help-add-device].

Nie potwierdzono (nie znalazłem oficjalnej tabeli):
- Czy WATCH 4 / WATCH 4 Pro uruchamiają HAP-y ArkTS "wearable". Wyszukiwanie sugeruje, że WATCH 4 Pro ma starszy system niezgodny z HarmonyOS NEXT, ale to nie jest oficjalna tabela.
- Czy WATCH Ultimate 2 i seria GT 5 / GT 6 są "lite" czy pełne. GT 5 jest opisany jako pierwszy z HarmonyOS 5, bez informacji, czy obsługuje HAP-y ArkTS.
- Czy zegarek musi być sparowany z telefonem lub Huawei Health, być zalogowany na Huawei ID albo spełniać warunek regionu, aby włączyć tryb dewelopera i debugowanie. Żaden z przewodników dla WATCH 5 tego nie wymaga (nie potwierdzono, że nie jest wymagane). Parowanie z telefonem jest wymagane tylko do odczytu UDID *sports watch* [D agc-help-add-device].

## 2. Tryb dewelopera na zegarku

Dwa źródła [F] opisują dokładnie WATCH 5 / zegarki wearable (nie ma oficjalnego dokumentu dla WATCH 5 po angielsku z pełnymi nazwami, więc kolejność i nazwy mogą się różnić w wersji 6.x):
1. Zegarek: Settings > (About / "Huawei Watch Rates" w tekście, najpewniej błąd tłumaczenia) > Software Version (inne źródło: "Build number"). Stuknąć 5–6 razy z rzędu, aż pojawi się komunikat "Developer Options are enabled" (inne źródło: "You are in Developer Mode!"). [F running-debugging...; F smartwatch Wi-Fi debugging; D agc-harmonyapp-debugharmonyapp: "Settings > About, keep tapping Build number"]
2. Settings > System > Developer options. Włączyć **HDC debugging** oraz **Debug via Wi-Fi** (wariant nazwy: **Debugging via WLAN**; wg dokumentu ogólnego "Wireless debugging or Debug via WLAN (for wearables)"). [D ide-run-device]
3. W sekcji Debug via Wi-Fi zegarek pokazuje `IP:port` (przykład w źródle: `192.x.x.x:5555`).

Dla telefonów/tabletów Huawei opisuje 7 stuknięć w wersję oprogramowania i restart [D ide-developer-mode]. Czy WATCH 5 restartuje się po włączeniu, nie potwierdzono.

USB przez stację ładującą: dokument mówi, że wearable (poza lite) obsługuje wyłącznie tryb bezprzewodowy [D ide-run-device]. Oniro dodaje, że zegarki "often have no USB data connection" [oniroproject real-device]. Żadne źródło nie opisuje stacji ładującej jako kanału USB. Tryb USB jest więc niedostępny.

## 3. Połączenie z PC

Warunki [D hdc, D ide-run-device]:
1. PC i zegarek w tej samej sieci Wi-Fi.
2. Odczyt `IP:port` z ekranu Debug via Wi-Fi zegarka.
3. Jedna z dróg:
   - **DevEco 6.1.1 Release (6.1.1.300) i nowsze:** Tools > IP Connection (albo "IP Connection" w liście urządzeń), wpisać `IP:port`, Connect. Po połączeniu ekran jest domyślnie zawsze włączony (DevEco wysyła stale instrukcję włączenia ekranu, nawet po ręcznym zablokowaniu). Wyłączenie: "Disable Screen Always-On" w panelu IP Connection albo rozłączenie. [D ide-run-device]
   - **Nowy DevEco 6.1.1 przed 6.1.1.300:** Tools > IP Connection, wpisać adres, zielona strzałka.
   - **hdc:** `hdc tconn <ip>:<port>`; oczekiwane: `Connect OK`. Inne wyniki: `[Info]Target is connected, repeat operation.`, `[Fail]Connect failed.` [D hdc]
4. Weryfikacja: `hdc list targets -v`. Wiersz ma format `connect-key  TCP  Connected  <nazwa>  hdc`. Dla Wi-Fi connect-key to `IP:port`. Stany: Unknown/Ready/Connected/Offline/Unauthorized. [D hdc]
5. Autoryzacja: przy pierwszym połączeniu zegarek ma pokazać prośbę o zaufanie ("Trust" / "Always trust"). [D ide-developer-mode: "authorization from the device is required"; D hdc FAQ]. Jeśli widać `Unauthorized`: wyłączyć i włączyć debugowanie bezprzewodowe w opcjach dewelopera albo `hdc kill -r`, i ponownie zatwierdzić. [D hdc FAQ]

Pułapki:
- DevEco zajmuje port 8710 swoim serwerem hdc. Przy błędach `Connect server failed`, `connect failed status:-4078` albo braku wyjścia: zamknąć oprogramowanie z wbudowanym hdc, sprawdzić `netstat -an | findstr 8710`, uruchomić `hdc kill`, upewnić się, że działa tylko jeden hdc.exe. [D hdc FAQ] To dotyczy też uruchamiania własnego hdc równolegle z DevEco [P]: użyć tego samego hdc co DevEco (`...\sdk\default\openharmony\toolchains\hdc.exe`).
- `[Fail]Failed to communicate with daemon` oznacza niezgodność hdc/SDK z urządzeniem albo zajęty port. Rozwiązanie z dokumentu: zaktualizować hdc/SDK. [D hdc FAQ]
- Dokument ostrzega: "The TCP debugging mode is not stable. You are advised to use it only in the test environment." [D hdc]
- Test ping z PC do zegarka. Jeśli DevEco nie łączy, wyłączyć i włączyć "debugging via WLAN" na zegarku. [F smartwatch Wi-Fi debugging]
- Hotspot z PC jako obejście: [F running-debugging...] podaje, że można "enable Hotspot from your PC and connect the Watch to it" albo użyć tej samej sieci. To obejście z forum użytkownika (nie z oficjalnej dokumentacji). Hotspot z telefonu Huawei nie jest opisany w źródłach (nie potwierdzono, choć to ta sama zasada).
- Izolacja klientów w sieciach publicznych/hackathonowych: żadne źródło tego nie opisuje; to moje wnioskowanie [P] z wymogu "same network" i testu `telnet IP:port`. Test z dokumentu: `telnet <ip> <port>` [D hdc].
- Źródło [F] zaleca stałe IP zegarka przez DHCP routera, bo połączenie IP często się zrywa.

## 4. Podpis dla prawdziwego urządzenia

Najpierw sprawdź [D ide-signing-auto]:
- Czas systemu PC musi być zsynchronizowany z czasem pekińskim (UTC+8), inaczej podpis się nie powiedzie. Chodzi o synchronizację z zewnętrznym wzorcem czasu (strefa czasowa nie ma znaczenia), ale dokument mówi dosłownie: "verify that your local system time is synchronized with Beijing Time (UTC/GMT+08:00)". Sprawdź zegar systemowy Windows przed próbą.
- Jeśli podłączonych jest kilka urządzeń, dane wszystkich trafiają do certyfikatu. Odłącz emulator (patrz też UDID poniżej).

### 4A. Automatyczny podpis (zalecany)
Ścieżka [D ide-signing-auto]: File > Project Structure... > Project > Signing Configs > zaznaczyć **Automatically generate signature** (NIE "Associate with registered application") > OK > przy pytaniu **Sign In** i zalogować Huawei ID. Zegarek musi być połączony (albo urządzenie zarejestrowane w AGC).
- Zaznacz też **Support HarmonyOS** (jeśli jest). Bez tego powstaje podpis OpenHarmony, który jest podpisem wydaniowym: "do not support debugging features such as debug log printing" i może powodować `fail to verify pkcs7 file`. [D ide-signing-auto; D faqs-app-debugging-6-V5]
- Wynik: lokalnie powstają `.p12` (keystore), `.csr`, `.cer`, `.p7b`. Informacje o podpisie trafiają do `signingConfigs` w `build-profile.json5` na poziomie projektu. Po najechaniu na ikonę przy "Provisioning Profile: DevEco Managed Profile" widać ważność certyfikatu, bundle name, ACL i możliwości. [D ide-signing-auto]
- Dokładnej lokalizacji plików na dysku dokument nie podaje (nie potwierdzono; zajrzyj do `signingConfigs` po podpisaniu).
- Okres ważności i limit urządzeń dla automatycznego podpisu: nie podano w dokumencie (nie potwierdzono). Wiem tylko, że tymczasowe profile (po zgłoszeniu ACL, przed zatwierdzeniem) mają krótką ważność.
- Uprawnienia: `READ_HEALTH_DATA` i `ACTIVITY_MOTION` są zwykłe (normal, user_grant), więc nie wymagają zgłoszenia ACL. Dodaj je do `requestPermissions` w `module.json5` (u ciebie już są).
- Wymóg real-name (weryfikacji tożsamości) dla automatycznego podpisu: nie wspomniany (nie potwierdzono). Przy ręcznym certyfikacie z AGC ma znaczenie, patrz 4B.

### 4B. Ręcznie (gdy automat zawiedzie)
[D ide-signing-manual, D agc-help-add-debugcert, D agc-help-add-device, D agc-harmonyapp-debugharmonyapp, F running-debugging...]
1. DevEco: Build > Generate Key and CSR (hasło min. 8 znaków z dwóch kategorii; zapisz alias i hasło). Powstaje `.p12` i `.csr`. Zalecane ważności 25+ lat dotyczą klucza.
2. UDID zegarka: `hdc shell bm get --udid` (zegarek połączony przez tconn; jeśli jest też emulator lub kilka urządzeń: `hdc -t <connect-key> shell bm get --udid`). Wynik: 64 znaki alfanumeryczne. Źródło [F] używa skróconego `bm get -u`; oficjalny dokument AGC podaje `--udid`.
3. AppGallery Connect > Certificates, app IDs, and profiles:
   - Certificates > New certificate > typ Debug certificate > wgraj `.csr` > pobierz `.cer`. Limit: 3 certyfikaty debug na konto [D agc-help-add-debugcert] (starszy dokument: 2 [D agc-harmonyapp-debugharmonyapp]).
   - **Ważność**: 1 rok po weryfikacji tożsamości (real-name), **14 dni bez weryfikacji tożsamości**. Po wygaśnięciu certyfikatu wszystkie profile z niego też są nieważne. [D agc-help-add-debugcert]
   - App IDs: nowa aplikacja HarmonyOS z bundle `com.fairwear.healthdemo` (ten sam, co w `app.json5`).
   - Devices > Add device: nazwa, typ Smart watch, UDID. **Limit: 100 urządzeń na konto na rok**; usunięte urządzenie liczy się do limitu przez rok. [D agc-help-add-device]
   - Profiles > Add: aplikacja, typ Debug, certyfikat, urządzenie > pobierz `.p7b`. Limit 100 profili na aplikację (wyszukiwanie).
4. DevEco: File > Project Structure > Project > Signing Configs. Odznacz "Automatically generate signature" i "Associate with registered application". Uzupełnij Store file (`.p12`), Store password, Key alias, Key password, Sign alg `SHA256withECDSA`, Profile file (`.p7b`), Certpath file (`.cer`). Apply. Ścieżki mogą być względne od katalogu projektu. [D ide-signing-manual]

## 5. Budowanie, instalacja, logi

Z DevEco: wybierz zegarek na liście urządzeń (nazwa typu `HUAWEI WATCH [192.168.x.x:5555]`), Run > Run 'entry' (Shift+F10). DevEco zbuduje, zainstaluje i uruchomi aplikację automatycznie. [D ide-run-device; F running-debugging...]

Z wiersza poleceń:
- Zadanie hvigor produkujące podpisany HAP i jego dokładną lokalizację wyjściową: nie potwierdzono w pobranych dokumentach (nie sprawdziłem pliku w Twoim projekcie, bo wymagało to uruchomienia buildu). Po podpisaniu w `build-profile.json5` zwykły `assembleHap` powinien dać podpisany HAP [P]. Sprawdź katalog `entry\build\default\outputs\default\` pod kątem pliku z "signed" w nazwie.
- Instalacja: `hdc install -r <ścieżka>.hap` [D hdc]. Wariant `hdc -t <IP:port> install -r ...` przy kilku urządzeniach.
- Uruchomienie: `hdc shell aa start -b com.fairwear.healthdemo -a EntryAbility` (przykład z dokumentu używa `com.example.myapplication` i `EntryAbility`; nazwę ability sprawdź w `module.json5`). [D hdc]
- Logi: `hdc hilog` (parametry jak `hilog -h`; filtr `-b D/I/W/E/F`, `-T <tag>`, `-D 0x<domain>`). Przełącznik prywatności `-p off` pokazuje wartości zamiast `<private>`. [D hdc, D hilog] Dokument hdc: aplikacje z podpisem wydaniowym nie obsługują logowania debug, więc podpis debug jest konieczny. Czy `hdc hilog` działa na komercyjnym zegarku bez roota dla aplikacji debug, nie potwierdzono w żadnym źródle (jest to normalny użytek dla aplikacji debug [P]).
- Zrzut ekranu (`snapshot_display`, `uitest screenCap`) i `uitest uiInput` na prawdziwym urządzeniu: **nie potwierdzono**. Dokument hdc wymienia `UItest` tylko jako narzędzie dostępne w powłoce (`UItest | UI test framework`), bez wzmianki o ograniczeniach na urządzeniach komercyjnych. Mój wniosek [P]: `hdc shell snapshot_display -f /data/local/tmp/s.jpeg` i `hdc file recv ...` to standardowa ścieżka, ale na zegarku niesprawdzona.

## 6. Limity zegarków komercyjnych

- HEART_RATE: forumowy wpis [F, Huawei Developer Forum / dev.to "Get heart rate with Sensor Kit..."] mówi, że kod z `sensor.on(sensor.SensorId.HEART_RATE, ...)` i uprawnieniem `READ_HEALTH_DATA` "Tested on the Huawei Watch 5 device. It works as expected." To pojedynczy wpis użytkownika. Autor podaje, że uprawnienie dopisuje się do `requestPermissions` z `usedScene.when: "inuse"` i trzeba je zażądać w czasie działania. Żeby zbudować uprawnienie z `reason`, potrzebny jest zasób stringu.
- Dokumentacja sensorów: HEART_RATE wymaga `READ_HEALTH_DATA`, PEDOMETER wymaga `ACTIVITY_MOTION`, oba user_grant [D sensor-overview]. Lista sensorów obejmuje też WEAR_DETECTION (bez uprawnienia w tabeli) i PEDOMETER_DETECTION.
- PEDOMETER i WEAR_DETECTION na prawdziwym WATCH 5 dla aplikacji trzecich: nie potwierdzono żadnym raportem.
- Ostrzeżenie z dokumentacji: częstotliwość próbkowania 5 ms–200 ms (5000000–200000000 ns), mniejsza wartość to większy pobór mocy [D sensor-guidelines]. Czujnik tętna fizycznie może raportować rzadziej [P].
- Zatrzymanie próbkowania po wygaszeniu ekranu: żaden materiał o HarmonyOS tego nie opisuje (nie potwierdzono). Wyniki wyszukiwania dotyczyły Wear OS i Apple Watch, nie HarmonyOS. Pamiętaj o efekcie ubocznym DevEco: po połączeniu z 6.1.1.300 ekran jest utrzymywany włączony, co maskuje ten problem w testach. Wyłącz to przed testem wygaszonego ekranu ("Disable Screen Always-On").
- Limity życia aplikacji debug: ważność certyfikatu debug 1 rok (po real-name) lub 14 dni (bez), a profil upada razem z certyfikatem [D agc-help-add-debugcert]. Dla automatycznego podpisu DevEco ważność nie jest podana (nie potwierdzono). Czy aplikacja debug jest usuwana z zegarka po N dniach, nie potwierdzono.

## Kolejność kroków dla właściciela (skrót)

1. Zegarek: Settings > About > stuknąć Software Version / Build number 5–6 razy.
2. Zegarek: Settings > System > Developer options > włączyć HDC debugging i Debug via Wi-Fi (WLAN); zapisać `IP:port`.
3. PC i zegarek w tej samej sieci; sprawdzić ping. Na PC sprawdzić czas systemowy.
4. DevEco: Tools > IP Connection > `IP:port` > Connect (lub `hdc tconn IP:port`), zatwierdzić "Trust" na zegarku; `hdc list targets -v` ma pokazać `TCP Connected`.
5. DevEco: File > Project Structure > Project > Signing Configs > Automatically generate signature (+ Support HarmonyOS) > Sign In Huawei ID > OK. Sprawdzić `signingConfigs` w `build-profile.json5`.
6. Run > Run 'entry' na zegarku; zatwierdzić na zegarku prośby o uprawnienia (health data, ruch).
7. Logi: `hdc hilog`.

## Czego nie udało się potwierdzić

- Oficjalna tabela modeli: WATCH 4 / 4 Pro, Ultimate 2, GT 5 / GT 6 jako cel dla HAP-ów ArkTS "wearable"; minimalna wersja systemu dla zegarka.
- Wymóg sparowania z telefonem, Huawei Health, zalogowania Huawei ID na zegarku, regionu zegarka.
- Dokładna nazwa menu "Settings > About" w HarmonyOS 5.1/6.x na WATCH 5 (źródła różnią się: "Software Version" / "Build number", a "Huawei Watch Rates" to oczywisty błąd tłumaczenia) oraz czy po włączeniu następuje restart.
- Dokładny komunikat odrzucenia całkowicie niepodpisanego HAP-a na prawdziwym zegarku (znany jedynie `9568257 fail to verify pkcs7 file` dla złego typu podpisu).
- Wpływ ustawienia regionu CN w DevEco na automatyczny podpis dla konta spoza Chin; wymóg real-name dla automatycznego podpisu; ważność i limit urządzeń przy automatycznym podpisie; lokalizacja wygenerowanych plików.
- Nazwa zadania hvigor i ścieżka podpisanego HAP-a (nie uruchamiałem buildu).
- Działanie `hdc hilog`, `snapshot_display`, `uitest screenCap`, `uitest uiInput` na komercyjnym zegarku; czy `hdc shell bm get --udid` działa na WATCH 5 (forum używa `bm get -u`, AGC `--udid`).
- Działanie PEDOMETER i WEAR_DETECTION dla aplikacji trzecich; zachowanie próbkowania po wygaszeniu ekranu; usuwanie aplikacji debug po N dniach.
- Izolacja klientów w sieci hackathonowej i hotspot z telefonu: tylko wnioskowanie, brak źródeł.

## Źródła
- [Running Your App on a Local Real Device (ide-run-device)](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-run-device)
- [Configuring a Debug Signature (ide-signing)](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-signing), [automatic (ide-signing-auto)](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-signing-auto), [manual (ide-signing-manual)](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-signing-manual)
- [Using Developer Options (ide-developer-mode)](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-developer-mode)
- hdc (id `hdc`), sensor-overview, sensor-guidelines, hilog, permissions-for-all-user, faqs-app-debugging-6-V5 w tym samym katalogu `harmonyos-guides` / `harmonyos-faqs-V5`
- AGC: [agc-help-add-debugcert-0000001914263178](https://developer.huawei.com/consumer/es/doc/app/agc-help-add-debugcert-0000001914263178), [agc-help-add-device-0000001946142249](https://developer.huawei.com/consumer/es/doc/app/agc-help-add-device-0000001946142249), [agc-harmonyapp-debugharmonyapp](https://developer.huawei.com/consumer/en/doc/agc-harmonyapp-debugharmonyapp)
- Forum Huawei (przez dev.to): [Running & Debugging HarmonyOS Apps on Huawei Watches](https://forums.developer.huawei.com/forumPortal/en/topic/0201194526496041065), [Build and Run Your First HarmonyOS Wearable App on Huawei Watch 5](https://forums.developer.huawei.com/forumPortal/en/topic/0201189851517240055), [Get heart rate with Sensor Kit](https://forums.developer.huawei.com/forumPortal/en/topic/0203191848058350005), [Smartwatch Wi-Fi debugging](https://forums.developer.huawei.com/forumPortal/en/topic/0201181900247497109), [code:9568257](https://forums.developer.huawei.com/forumPortal/en/topic/0201180614826994080)
- [Oniro: run on real wearable device](https://docs.oniroproject.org/application-development/environment-setup-guide/deveco-studio/real-device/), [Oniro heart rate codelab](https://docs.oniroproject.org/application-development/codeLabs/wearable/health/)
- Surowe pliki pobranych dokumentów (JSON, tekst) leżą w katalogu scratchpad: `C:\Users\robac\AppData\Local\Temp\claude\C--Users-robac\30703d26-dc8d-4c6d-8fee-2dcb51d83310\scratchpad\` (m.in. `hdc.txt`, `ide-run-device.json`, `ide-signing-auto.json`, `ide-signing-manual.json`).
