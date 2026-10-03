import { BusinessError } from '@kit.BasicServicesKit';
import {
  AnomalyFlag, Consents, DayState, DayView, Evaluation, LabeledValue, Persona, Severity, WeekStatus, WeekSummary
} from '../model/Types';
import { Personas } from '../model/Personas';
import { shortDate, yesterdayIso } from '../model/DateUtil';
import { Evaluator } from '../logic/Evaluator';
import { Labels } from '../logic/Labels';
import { CheckItem, ProofToken, VerificationResult } from '../logic/ProofToken';
import { LiveSnapshot } from '../logic/LiveDayCollector';
import { b64urlDecode } from '../logic/Codec';
import { CryptoUtil } from '../platform/CryptoUtil';
import { DeviceKey, KeySource, ProofSigner } from '../platform/ProofSigner';
import { SensorAvailability, SensorSource } from '../platform/SensorSource';
import { PermissionHelper } from '../platform/Permissions';

/*
 * Dowód aktywności - jedna strona, 5 zakładek:
 *  Zgody -> Tygodnie -> Kontrola -> Raport (podpis + QR) -> Ubezpieczyciel (weryfikacja + decyzja człowieka).
 * Zasada UI: @Builder dostaje tylko stałe parametry, a dane dynamiczne czyta z this.* (inaczej ArkUI ich nie odświeża).
 */

const C_BG: string = '#F3F5F7';
const C_CARD: string = '#FFFFFF';
const C_TEXT: string = '#16202A';
const C_MUTED: string = '#5B6773';
const C_LINE: string = '#E1E6EB';
const C_ACCENT: string = '#0B7A5C';
const C_ACCENT_SOFT: string = '#E3F3EE';
const C_WARN: string = '#9A5800';
const C_WARN_SOFT: string = '#FFF3DF';
const C_BAD: string = '#B3261E';
const C_BAD_SOFT: string = '#FCE8E6';
const C_GOLD: string = '#8A6400';
const C_GOLD_SOFT: string = '#FFF5D6';
const C_NEUTRAL_SOFT: string = '#EEF1F4';

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

@Extend(Button)
function primaryButton() {
  .width('100%')
  .height(44)
  .fontSize(15)
  .fontColor('#FFFFFF')
  .backgroundColor('#0B7A5C')
}

@Extend(Button)
function secondaryButton() {
  .width('100%')
  .height(44)
  .fontSize(15)
  .fontColor('#0B7A5C')
  .backgroundColor('#E3F3EE')
}

@Extend(Button)
function dangerButton() {
  .width('100%')
  .height(44)
  .fontSize(15)
  .fontColor('#B3261E')
  .backgroundColor('#FCE8E6')
}

@Entry
@Component
struct Index {
  private personas: Persona[] = Personas.all(yesterdayIso(Date.now()));
  private signer: ProofSigner = new ProofSigner();
  private sensors: SensorSource = new SensorSource();
  private tabsController: TabsController = new TabsController();
  private tickTimer: number = -1;
  private simTimer: number = -1;
  private simSteps: number = 0;
  private simSecond: number = 0;

  @State tabIndex: number = 0;
  @State personaIndex: number = 0;
  @State consentHr: boolean = true;
  @State consentSleep: boolean = false;
  @State policy: string = 'NNW-2026-004213';
  @State evaluation: Evaluation = new Evaluation();

  @State deviceKey: DeviceKey = new DeviceKey('', '', KeySource.SOFTWARE, false, '', 0);
  @State keyBusy: boolean = false;
  @State note: string = '';
  @State token: string = '';
  @State tokenRows: LabeledValue[] = [];
  @State signError: string = '';
  @State showRaw: boolean = false;

  @State insurerNonce: string = '';
  @State registeredKeys: DeviceKey[] = [];
  @State inbox: string = '';
  @State verification: VerificationResult = new VerificationResult();
  @State verified: boolean = false;
  @State verifyBusy: boolean = false;
  @State reviewDone: boolean = false;
  @State decisionLog: string[] = [];

  @State availability: SensorAvailability = new SensorAvailability();
  @State probed: boolean = false;
  @State live: LiveSnapshot = new LiveSnapshot();
  @State liveMode: string = '';
  @State liveErrors: string = '';

  aboutToAppear(): void {
    this.recompute();
    this.newInsurerRequest();
    SensorSource.probe().then((a: SensorAvailability) => {
      this.availability = a;
      this.probed = true;
    });
  }

  aboutToDisappear(): void {
    this.stopLive();
  }

  // ---------- stan i akcje ----------

  currentPersona(): Persona {
    return this.personas[this.personaIndex];
  }

  recompute(): void {
    this.evaluation = Evaluator.evaluate(this.currentPersona().days, new Consents(this.consentHr, this.consentSleep));
    this.token = '';
    this.tokenRows = [];
    this.signError = '';
  }

  selectPersona(index: number): void {
    this.personaIndex = index;
    this.note = '';
    this.recompute();
  }

  setConsent(which: number, isOn: boolean): void {
    if (which === 1) {
      this.consentHr = isOn;
    } else if (which === 2) {
      this.consentSleep = isOn;
    }
    this.recompute();
  }

  consentValue(which: number): boolean {
    if (which === 1) {
      return this.consentHr;
    }
    if (which === 2) {
      return this.consentSleep;
    }
    return true;
  }

  clock(): string {
    const d = new Date();
    return `${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
  }

  async newInsurerRequest(): Promise<void> {
    this.insurerNonce = await CryptoUtil.randomHex(4);
    this.verified = false;
    this.reviewDone = false;
  }

  hasKey(): boolean {
    return this.deviceKey.kid.length > 0;
  }

  findRegistered(kid: string): DeviceKey | null {
    for (const k of this.registeredKeys) {
      if (k.kid === kid) {
        return k;
      }
    }
    return null;
  }

  async registerDevice(): Promise<void> {
    this.keyBusy = true;
    try {
      const key = await this.signer.ensureKey(this.insurerNonce.length > 0 ? this.insurerNonce : 'rejestracja');
      this.deviceKey = key;
      if (this.findRegistered(key.kid) === null) {
        // Ubezpieczyciel dostaje własną kopię: tylko kid i klucz publiczny.
        this.registeredKeys.push(new DeviceKey(key.kid, key.publicKeyB64, key.source, key.attested, key.note,
          key.certCount));
      }
      this.signError = '';
    } catch (e) {
      this.signError = `Nie udało się utworzyć klucza: ${ProofSigner.errText(e as BusinessError)}`;
    }
    this.keyBusy = false;
  }

  async signReport(): Promise<void> {
    if (!this.hasKey()) {
      await this.registerDevice();
      if (!this.hasKey()) {
        return;
      }
    }
    this.keyBusy = true;
    try {
      const payload = ProofToken.buildPayload(this.evaluation, this.policy, this.insurerNonce, this.note,
        this.deviceKey.kid, Date.now());
      const bytes = ProofToken.payloadBytes(payload);
      const signature = await this.signer.sign(bytes);
      const token = ProofToken.encode(bytes, signature);
      const parsed = ProofToken.parse(token);
      this.tokenRows = parsed.payload !== null ? ProofToken.describe(parsed.payload) : [];
      this.token = token;
      this.signError = '';
    } catch (e) {
      this.signError = `Podpis nie powiódł się: ${ProofSigner.errText(e as BusinessError)}`;
    }
    this.keyBusy = false;
  }

  sendToInsurer(): void {
    this.inbox = this.token;
    this.verified = false;
    this.reviewDone = false;
    this.tabsController.changeIndex(4);
  }

  async verifyInbox(): Promise<void> {
    this.verifyBusy = true;
    this.verified = false;
    const parsed = ProofToken.parse(this.inbox);
    let keyKnown = false;
    let sigOk = false;
    if (parsed.ok && parsed.payload !== null) {
      const key = this.findRegistered(parsed.payload.kid);
      if (key !== null) {
        keyKnown = true;
        sigOk = await CryptoUtil.verifyEcdsaP256(b64urlDecode(key.publicKeyB64), parsed.payloadBytes, parsed.sigBytes);
      }
    }
    this.verification = ProofToken.check(parsed, keyKnown, sigOk, this.insurerNonce, Date.now());
    this.verified = true;
    this.reviewDone = false;
    if (this.verification.ok && this.vStatus() === 'OK') {
      this.decisionLog.push(`${this.clock()} · automat: próg ${Labels.tierShort(this.vTier())}, ` +
        `zniżka ${Labels.exampleDiscountPct(this.vTier())}% (zmiana tylko na korzyść klienta)`);
    } else if (!this.verification.ok) {
      this.decisionLog.push(`${this.clock()} · raport odrzucony: ${this.failedChecks()}`);
    }
    this.verifyBusy = false;
  }

  async tamperAndVerify(): Promise<void> {
    const source = this.inbox.length > 0 ? this.inbox : this.token;
    if (source.length === 0) {
      return;
    }
    this.inbox = ProofToken.tamper(source);
    await this.verifyInbox();
  }

  decide(text: string): void {
    this.decisionLog.push(`${this.clock()} · człowiek (underwriter): ${text}`);
    this.reviewDone = true;
  }

  vTier(): string {
    const p = this.verification.payload;
    return p !== null ? p.tier : '';
  }

  vStatus(): string {
    const p = this.verification.payload;
    return p !== null ? p.st : '';
  }

  vFlags(): string {
    const p = this.verification.payload;
    return p !== null && p.flags.length > 0 ? Labels.flagSummary(p.flags) : 'brak';
  }

  vNote(): string {
    const p = this.verification.payload;
    return p !== null && p.note !== undefined ? p.note : '';
  }

  reviewRows(): LabeledValue[] {
    const rows: LabeledValue[] = [];
    rows.push(new LabeledValue('Podejrzane dni', this.vFlags()));
    rows.push(new LabeledValue('Próg wstępny (bez podejrzanych tygodni)', Labels.tierShort(this.vTier())));
    if (this.vNote().length > 0) {
      rows.push(new LabeledValue('Wyjaśnienie klienta', this.vNote()));
    }
    return rows;
  }

  failedChecks(): string {
    const names: string[] = [];
    for (const c of this.verification.items) {
      if (!c.passed) {
        names.push(c.name.toLowerCase());
      }
    }
    return names.join(', ');
  }

  // ---------- czujniki na żywo ----------

  async startSensors(): Promise<void> {
    this.stopLive();
    const outcome = await PermissionHelper.request(getContext(this), PermissionHelper.forConsents(this.consentHr));
    const started = this.sensors.start(this.availability, this.consentHr);
    const problems: string[] = [];
    if (outcome.error.length > 0) {
      problems.push(`Uprawnienia: ${outcome.error}`);
    }
    for (const p of outcome.denied) {
      problems.push(`Odmówiono: ${p}`);
    }
    for (const e of this.sensors.errors) {
      problems.push(e);
    }
    if (started === 0) {
      problems.push('Żaden czujnik nie wystartował — użyj symulacji');
    }
    this.liveErrors = problems.join(' · ');
    if (started > 0) {
      this.liveMode = 'SENSORS';
      this.startTicker();
    }
  }

  startSimulation(fake: boolean): void {
    this.stopLive();
    this.liveErrors = '';
    this.sensors.collector.reset();
    this.sensors.collector.setWorn(1);
    this.simSteps = 1000;
    this.simSecond = 0;
    this.liveMode = fake ? 'SIM_FAKE' : 'SIM_OK';
    this.simTimer = setInterval(() => {
      this.simSecond++;
      this.simSteps += 2;
      const now = Date.now();
      this.sensors.collector.addPedometer(this.simSteps, now);
      if (this.consentHr) {
        const hr = fake ? 63 + (this.simSecond % 3) : (this.simSecond < 8 ? 70 : 104 + (this.simSecond % 5));
        this.sensors.collector.addHeartRate(hr, now);
      }
    }, 1000);
    this.startTicker();
  }

  takeWatchOff(): void {
    this.sensors.collector.setWorn(0);
  }

  startTicker(): void {
    this.live = this.sensors.collector.snapshot(Date.now());
    this.tickTimer = setInterval(() => {
      this.live = this.sensors.collector.snapshot(Date.now());
    }, 1000);
  }

  stopLive(): void {
    if (this.simTimer >= 0) {
      clearInterval(this.simTimer);
      this.simTimer = -1;
    }
    if (this.tickTimer >= 0) {
      clearInterval(this.tickTimer);
      this.tickTimer = -1;
    }
    this.sensors.stop();
    this.liveMode = '';
  }

  // ---------- pomocnicze dla widoku ----------

  consentEffects(): LabeledValue[] {
    const ev = this.evaluation;
    const rows: LabeledValue[] = [];
    rows.push(new LabeledValue('Poziom pewności', Labels.assurance(ev.assurance)));
    rows.push(new LabeledValue('Reguły antyoszustwa', `${ev.rulesRun.length} z 4`));
    rows.push(new LabeledValue('Zostaje na telefonie',
      ev.hrReadingsOnDevice > 0 ? `${ev.daysOnDevice} dni pomiarów, ok. ${Math.round(ev.hrReadingsOnDevice / 1000)} tys. odczytów tętna` :
        `${ev.daysOnDevice} dni pomiarów ruchu`));
    rows.push(new LabeledValue('Wychodzi z telefonu', 'Tylko podpisany wynik (zakładka Raport)'));
    return rows;
  }

  keyRows(): LabeledValue[] {
    const k = this.deviceKey;
    const rows: LabeledValue[] = [];
    rows.push(new LabeledValue('Identyfikator (kid)', k.kid));
    rows.push(new LabeledValue('Gdzie jest klucz prywatny',
      k.source === KeySource.HUKS ? 'HUKS — systemowy keystore, nie do wyjęcia' : 'Pamięć aplikacji (tryb awaryjny)'));
    rows.push(new LabeledValue('Atestacja', k.attested ? `tak, ${k.certCount} certyfikatów` : 'nie'));
    rows.push(new LabeledValue('Zarejestrowany u ubezpieczyciela',
      this.findRegistered(k.kid) !== null ? 'tak (tylko klucz publiczny)' : 'nie'));
    return rows;
  }

  liveRows(): LabeledValue[] {
    const s = this.live;
    const rows: LabeledValue[] = [];
    rows.push(new LabeledValue('Kroki w sesji', `${s.stepsSession}`));
    rows.push(new LabeledValue('Kroki / min (ostatnia minuta)', `${s.stepsPerMinute}`));
    rows.push(new LabeledValue('Tętno teraz / średnio', s.heartRate > 0 ? `${s.heartRate} / ${s.hrAvg60}` :
      (this.consentHr ? '— (czekam)' : '— (brak zgody na tętno)')));
    rows.push(new LabeledValue('Tętno spoczynkowe (szac.)', s.restingEstimate > 0 ? `${s.restingEstimate}` : '—'));
    rows.push(new LabeledValue('Zegarek na nadgarstku', s.worn === 1 ? 'tak' : (s.worn === 0 ? 'NIE' : 'nieznane')));
    return rows;
  }

  sensorSummary(): string {
    if (!this.probed) {
      return 'Sprawdzam czujniki…';
    }
    const a = this.availability;
    if (!a.anyUseful()) {
      return a.listError.length > 0 ? `Nie udało się odczytać listy czujników (${a.listError}). Użyj symulacji.` :
        `Brak krokomierza, tętna i wykrywania noszenia (${a.count} czujników) — typowe dla emulatora. Użyj symulacji.`;
    }
    return `Krokomierz ${a.pedometer ? '✓' : '✗'} · Tętno ${a.heartRate ? '✓' : '✗'} · Noszenie ${a.wear ? '✓' : '✗'}`;
  }

  liveModeLabel(): string {
    if (this.liveMode === 'SENSORS') {
      return 'Źródło: prawdziwe czujniki OpenHarmony';
    }
    if (this.liveMode === 'SIM_OK') {
      return 'Źródło: symulacja normalnego marszu';
    }
    if (this.liveMode === 'SIM_FAKE') {
      return 'Źródło: symulacja oszustwa (zegarek na wiertarce)';
    }
    return '';
  }

  barHeight(steps: number): number {
    return Math.max(4, Math.min(56, Math.round(56 * Math.sqrt(Math.max(0, steps) / 30000))));
  }

  dayColor(state: DayState): string {
    if (state === DayState.FLAGGED) {
      return C_BAD;
    }
    if (state === DayState.SKIPPED) {
      return '#C3CBD3';
    }
    return '#2E9E7B';
  }

  weekColor(status: WeekStatus): string {
    if (status === WeekStatus.MET) {
      return C_ACCENT;
    }
    if (status === WeekStatus.REVIEW) {
      return C_WARN;
    }
    return C_MUTED;
  }

  weekBg(status: WeekStatus): string {
    if (status === WeekStatus.MET) {
      return C_ACCENT_SOFT;
    }
    if (status === WeekStatus.REVIEW) {
      return C_WARN_SOFT;
    }
    return C_NEUTRAL_SOFT;
  }

  headerChipText(): string {
    return this.evaluation.status === 'REVIEW' ? 'Do przeglądu' : Labels.tierShort(this.evaluation.tier);
  }

  headerChipColor(): string {
    if (this.evaluation.status === 'REVIEW') {
      return C_WARN;
    }
    return this.evaluation.tier === 'ZLOTY' ? C_GOLD : (this.evaluation.tier === 'SREBRNY' ? C_MUTED : C_MUTED);
  }

  headerChipBg(): string {
    if (this.evaluation.status === 'REVIEW') {
      return C_WARN_SOFT;
    }
    return this.evaluation.tier === 'ZLOTY' ? C_GOLD_SOFT : C_NEUTRAL_SOFT;
  }

  // ---------- widok ----------

  @Styles
  cardStyle() {
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  build() {
    Column() {
      this.header()
      Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
        TabContent() {
          this.consentTab()
        }.tabBar(this.tabItem(0, 'Zgody'))

        TabContent() {
          this.weeksTab()
        }.tabBar(this.tabItem(1, 'Tygodnie'))

        TabContent() {
          this.checkTab()
        }.tabBar(this.tabItem(2, 'Kontrola'))

        TabContent() {
          this.reportTab()
        }.tabBar(this.tabItem(3, 'Raport'))

        TabContent() {
          this.insurerTab()
        }.tabBar(this.tabItem(4, 'Ubezpieczyciel'))
      }
      .layoutWeight(1)
      .barHeight(56)
      .barBackgroundColor(C_CARD)
      .onChange((index: number) => {
        this.tabIndex = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C_BG)
  }

  @Builder
  tabItem(index: number, title: string) {
    Column() {
      Text(title)
        .fontSize(12)
        .maxLines(1)
        .fontColor(this.tabIndex === index ? C_ACCENT : C_MUTED)
        .fontWeight(this.tabIndex === index ? FontWeight.Bold : FontWeight.Normal)
      Divider()
        .strokeWidth(3)
        .color(C_ACCENT)
        .width(24)
        .margin({ top: 6 })
        .opacity(this.tabIndex === index ? 1 : 0)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  header() {
    Row() {
      Column() {
        Text('Dowód aktywności')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(C_TEXT)
        Text(`${this.currentPersona().name} · surowe dane zostają na telefonie`)
          .fontSize(12)
          .fontColor(C_MUTED)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.headerChipText())
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.headerChipColor())
        .backgroundColor(this.headerChipBg())
        .borderRadius(14)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(C_CARD)
  }

  @Builder
  sectionTitle(title: string, subtitle: string) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(C_TEXT)
      if (subtitle.length > 0) {
        Text(subtitle)
          .fontSize(13)
          .fontColor(C_MUTED)
          .margin({ top: 4 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  kvRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(13)
        .fontColor(C_MUTED)
        .layoutWeight(1)
      Text(value)
        .fontSize(13)
        .fontColor(C_TEXT)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
        .layoutWeight(1.4)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 6, bottom: 6 })
  }

  // ---------- zakładka: Zgody ----------

  @Builder
  consentTab() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 10 }) {
          this.sectionTitle('Kto korzysta?', 'Dane syntetyczne w formacie agregatów z czujników — do demo na emulatorze')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.personas, (p: Persona, i: number) => {
              this.personaChip(p, i)
            }, (p: Persona) => p.id)
          }
          .width('100%')

          Text(this.currentPersona().tagline)
            .fontSize(14)
            .fontColor(C_TEXT)
            .width('100%')
          Text(`Oczekiwany wynik: ${this.currentPersona().expectation}`)
            .fontSize(13)
            .fontColor(C_MUTED)
            .width('100%')
        }
        .cardStyle()

        Column({ space: 4 }) {
          this.sectionTitle('Co udostępniasz do obliczeń na telefonie', 'Każda zgoda = osobne uprawnienie systemowe')
          this.consentRow(0, 'Ruch', 'Kroki, minuty aktywności, noszenie zegarka — wymagane')
          this.consentRow(1, 'Tętno', 'Wykrywa oszustwa → pełny poziom pewności i próg Złoty')
          this.consentRow(2, 'Sen', 'Dodaje do raportu liczbę tygodni ze snem 7+ h')
          Divider().color(C_LINE).margin({ top: 6, bottom: 6 })
          this.blockedRow('Cykl menstruacyjny', 'Nie zbieramy — składka w UE nie może zależeć od płci')
          this.blockedRow('Trasy GPS i lokalizacja', 'Nie zbieramy — niepotrzebne do oceny aktywności')
        }
        .cardStyle()

        Column() {
          this.sectionTitle('Efekt Twoich zgód', '')
          ForEach(this.consentEffects(), (r: LabeledValue) => {
            this.kvRow(r.label, r.value)
          }, (r: LabeledValue) => `${r.label}=${r.value}`)
        }
        .cardStyle()

        Column({ space: 8 }) {
          this.sectionTitle('Polisa', 'Na start NNW — wycena polis na życie i zdrowotnych to AI wysokiego ryzyka (AI Act)')
          TextInput({ text: this.policy, placeholder: 'Numer polisy' })
            .maxLength(ProofToken.POLICY_MAX_CHARS)
            .onChange((value: string) => {
              this.policy = value;
              this.token = '';
            })
        }
        .cardStyle()
      }
      .padding(16)
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  @Builder
  personaChip(p: Persona, i: number) {
    Text(p.name)
      .fontSize(13)
      .fontColor(this.personaIndex === i ? '#FFFFFF' : C_TEXT)
      .backgroundColor(this.personaIndex === i ? C_ACCENT : C_NEUTRAL_SOFT)
      .borderRadius(18)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.selectPersona(i);
      })
  }

  @Builder
  consentRow(which: number, title: string, subtitle: string) {
    Row({ space: 12 }) {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor(C_TEXT)
        Text(subtitle)
          .fontSize(12)
          .fontColor(C_MUTED)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.consentValue(which) })
        .selectedColor(C_ACCENT)
        .enabled(which !== 0)
        .onChange((isOn: boolean) => {
          this.setConsent(which, isOn);
        })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  blockedRow(title: string, subtitle: string) {
    Row({ space: 12 }) {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor(C_MUTED)
          .decoration({ type: TextDecorationType.LineThrough, color: C_MUTED })
        Text(subtitle)
          .fontSize(12)
          .fontColor(C_MUTED)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: false })
        .enabled(false)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  // ---------- zakładka: Tygodnie ----------

  @Builder
  weeksTab() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 6 }) {
          Text(`${this.evaluation.weeksMet} z ${this.evaluation.weeks.length} tygodni zaliczonych`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(C_TEXT)
            .width('100%')
          Text(this.evaluation.periodFrom.length > 0 ?
            `Okres ${shortDate(this.evaluation.periodFrom)} – ${shortDate(this.evaluation.periodTo)} · ` +
              `Twoja baza: ${this.evaluation.baselineAvgSteps} kroków/dzień` : 'Brak danych')
            .fontSize(13)
            .fontColor(C_MUTED)
            .width('100%')
          Text('Tydzień zaliczony: 150+ min aktywności albo +10% kroków względem własnej bazy. ' +
            'Złoty = 3 z 4 tygodni, więc tydzień choroby nie odbiera zniżki. Brak danych nie karze.')
            .fontSize(13)
            .fontColor(C_TEXT)
            .width('100%')
            .margin({ top: 4 })
        }
        .cardStyle()

        ForEach(this.evaluation.weeks, (w: WeekSummary) => {
          this.weekCard(w)
        }, (w: WeekSummary) => `${this.personaIndex}|${w.index}|${w.status}|${w.reason}|${w.avgSteps}|${w.validDays}`)

        Row({ space: 16 }) {
          this.legendDot('#2E9E7B', 'dzień liczony')
          this.legendDot('#C3CBD3', 'pominięty')
          this.legendDot(C_BAD, 'podejrzany')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .padding(16)
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  @Builder
  weekCard(w: WeekSummary) {
    Column({ space: 10 }) {
      Row() {
        Text(`Tydzień ${w.index}`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(C_TEXT)
        Text(`  ${shortDate(w.from)}–${shortDate(w.to)}`)
          .fontSize(13)
          .fontColor(C_MUTED)
        Blank()
        Text(Labels.weekStatus(w.status))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.weekColor(w.status))
          .backgroundColor(this.weekBg(w.status))
          .borderRadius(12)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      }
      .width('100%')

      Row({ space: 6 }) {
        ForEach(w.days, (d: DayView) => {
          Column() {
            Column()
              .width('100%')
              .height(this.barHeight(d.steps))
              .backgroundColor(this.dayColor(d.state))
              .borderRadius(4)
          }
          .layoutWeight(1)
          .height(56)
          .justifyContent(FlexAlign.End)
        }, (d: DayView) => `${d.date}|${d.state}|${d.steps}`)
      }
      .width('100%')
      .height(56)

      Text(w.reason)
        .fontSize(13)
        .fontColor(C_TEXT)
        .width('100%')
      Text(`${w.avgSteps} kroków/dzień · ${w.weeklyActiveMinutes} min aktywności/tydz. · ${w.validDays}/7 dni liczonych` +
        (this.consentSleep && w.avgSleepMinutes > 0 ?
          ` · sen ${Math.floor(w.avgSleepMinutes / 60)} h ${w.avgSleepMinutes % 60} min` : ''))
        .fontSize(12)
        .fontColor(C_MUTED)
        .width('100%')
    }
    .cardStyle()
  }

  @Builder
  legendDot(color: string, label: string) {
    Row({ space: 6 }) {
      Column()
        .width(10)
        .height(10)
        .borderRadius(3)
        .backgroundColor(color)
      Text(label)
        .fontSize(12)
        .fontColor(C_MUTED)
    }
  }

  // ---------- zakładka: Kontrola ----------

  @Builder
  checkTab() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 6 }) {
          this.sectionTitle('Reguły uruchomione na telefonie', 'Reguły zamiast czarnej skrzynki: każdą decyzję da się wyjaśnić klientowi')
          ForEach(this.evaluation.rulesRun, (r: string) => {
            Row({ space: 8 }) {
              Text('✓')
                .fontSize(14)
                .fontColor(C_ACCENT)
                .fontWeight(FontWeight.Bold)
              Text(r)
                .fontSize(13)
                .fontColor(C_TEXT)
                .layoutWeight(1)
            }
            .width('100%')
          }, (r: string) => r)
          if (!this.consentHr) {
            Text('Bez zgody na tętno reguła „kroki bez wzrostu tętna” nie działa — dlatego próg jest ograniczony do Srebrnego.')
              .fontSize(13)
              .fontColor(C_WARN)
              .backgroundColor(C_WARN_SOFT)
              .borderRadius(10)
              .padding(10)
              .width('100%')
              .margin({ top: 6 })
          }
        }
        .cardStyle()

        Column({ space: 8 }) {
          Text(`Wykryte zdarzenia (${this.evaluation.flags.length})`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(C_TEXT)
            .width('100%')
          Text(this.evaluation.flags.length === 0 ? 'Brak — wszystkie dni wiarygodne' :
            'Podejrzane dni idą do człowieka; za krótko noszone są pomijane bez kary')
            .fontSize(13)
            .fontColor(C_MUTED)
            .width('100%')
          ForEach(this.evaluation.flags, (f: AnomalyFlag) => {
            this.flagRow(f)
          }, (f: AnomalyFlag) => `${this.personaIndex}|${f.date}|${f.code}|${f.severity}`)
        }
        .cardStyle()

        this.liveCard()
      }
      .padding(16)
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  @Builder
  flagRow(f: AnomalyFlag) {
    Row({ space: 10 }) {
      Column()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(f.severity === Severity.HIGH ? C_BAD : '#C3CBD3')
        .margin({ top: 6 })
      Column({ space: 2 }) {
        Text(`${shortDate(f.date)} · ${Labels.flag(f.code)}`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(f.severity === Severity.HIGH ? C_BAD : C_TEXT)
        Text(f.detail)
          .fontSize(12)
          .fontColor(C_MUTED)
        Text(f.severity === Severity.HIGH ? 'Tydzień trafi do przeglądu przez człowieka' : 'Dzień pominięty, bez kary')
          .fontSize(12)
          .fontColor(f.severity === Severity.HIGH ? C_WARN : C_MUTED)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  liveCard() {
    Column({ space: 10 }) {
      this.sectionTitle('Czujniki na żywo', 'Ten sam detektor na odczytach z ostatniej minuty')
      Text(this.sensorSummary())
        .fontSize(13)
        .fontColor(C_TEXT)
        .width('100%')
      Button('Uruchom prawdziwe czujniki')
        .primaryButton()
        .enabled(this.availability.anyUseful())
        .opacity(this.availability.anyUseful() ? 1 : 0.4)
        .onClick(() => {
          this.startSensors();
        })
      Row({ space: 8 }) {
        Button('Symuluj marsz')
          .secondaryButton()
          .layoutWeight(1)
          .onClick(() => {
            this.startSimulation(false);
          })
        Button('Symuluj oszustwo')
          .dangerButton()
          .layoutWeight(1)
          .onClick(() => {
            this.startSimulation(true);
          })
      }
      .width('100%')

      if (this.liveMode !== '') {
        Text(this.liveModeLabel())
          .fontSize(12)
          .fontColor(C_MUTED)
          .width('100%')
        Text(this.live.verdict)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.live.suspicious ? C_BAD : C_ACCENT)
          .backgroundColor(this.live.suspicious ? C_BAD_SOFT : C_ACCENT_SOFT)
          .borderRadius(10)
          .padding(12)
          .width('100%')
        ForEach(this.liveRows(), (r: LabeledValue) => {
          this.kvRow(r.label, r.value)
        }, (r: LabeledValue) => `${r.label}=${r.value}`)
        Row({ space: 8 }) {
          if (this.liveMode !== 'SENSORS') {
            Button('Zdejmij zegarek')
              .secondaryButton()
              .layoutWeight(1)
              .onClick(() => {
                this.takeWatchOff();
              })
          }
          Button('Stop')
            .secondaryButton()
            .layoutWeight(1)
            .onClick(() => {
              this.stopLive();
            })
        }
        .width('100%')
      }
      if (this.liveErrors.length > 0) {
        Text(this.liveErrors)
          .fontSize(12)
          .fontColor(C_WARN)
          .width('100%')
      }
    }
    .cardStyle()
  }

  // ---------- zakładka: Raport ----------

  @Builder
  reportTab() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 8 }) {
          this.sectionTitle('1. Klucz urządzenia',
            'ECC P-256 w HUKS (Universal Keystore). Klucz prywatny nie opuszcza urządzenia; ubezpieczyciel dostaje raz klucz publiczny.')
          if (this.hasKey()) {
            ForEach(this.keyRows(), (r: LabeledValue) => {
              this.kvRow(r.label, r.value)
            }, (r: LabeledValue) => `${r.label}=${r.value}`)
            Text(this.deviceKey.note)
              .fontSize(12)
              .fontColor(this.deviceKey.source === KeySource.HUKS ? C_MUTED : C_WARN)
              .width('100%')
          } else {
            Button(this.keyBusy ? 'Tworzę klucz…' : 'Utwórz klucz i zarejestruj u ubezpieczyciela')
              .primaryButton()
              .enabled(!this.keyBusy)
              .onClick(() => {
                this.registerDevice();
              })
          }
        }
        .cardStyle()

        Column({ space: 8 }) {
          this.sectionTitle('2. Odpowiedź na żądanie ubezpieczyciela',
            'Raport podpisany pod inne żądanie nie przejdzie weryfikacji')
          Text(`Nonce żądania: ${this.insurerNonce}`)
            .fontSize(13)
            .fontFamily('monospace')
            .fontColor(C_TEXT)
            .width('100%')
          TextInput({ text: this.note, placeholder: 'Wyjaśnienie dla ubezpieczyciela (opcjonalnie, maks. 40 znaków)' })
            .maxLength(ProofToken.NOTE_MAX_CHARS)
            .onChange((value: string) => {
              this.note = value;
            })
          Button(this.keyBusy ? 'Podpisuję…' : 'Podpisz raport kluczem urządzenia')
            .primaryButton()
            .enabled(!this.keyBusy)
            .onClick(() => {
              this.signReport();
            })
          if (this.signError.length > 0) {
            Text(this.signError)
              .fontSize(13)
              .fontColor(C_BAD)
              .width('100%')
          }
        }
        .cardStyle()

        if (this.token.length > 0) {
          Column() {
            this.sectionTitle('3. Co dokładnie wychodzi z telefonu', 'Tylko te pola, podpisane. Żadnych dziennych wartości ani dat dni.')
            ForEach(this.tokenRows, (r: LabeledValue) => {
              this.kvRow(r.label, r.value)
            }, (r: LabeledValue) => `${r.label}=${r.value}`)
            Text(`Zostaje na telefonie: ${this.evaluation.daysOnDevice} dni pomiarów` +
              (this.evaluation.hrReadingsOnDevice > 0 ?
                `, ok. ${Math.round(this.evaluation.hrReadingsOnDevice / 1000)} tys. odczytów tętna` : ''))
              .fontSize(12)
              .fontColor(C_ACCENT)
              .backgroundColor(C_ACCENT_SOFT)
              .borderRadius(10)
              .padding(10)
              .width('100%')
              .margin({ top: 8 })
          }
          .cardStyle()

          Column({ space: 10 }) {
            this.sectionTitle('4. Kod QR dla ubezpieczyciela', '')
            Text(`${this.token.length} / ${ProofToken.QR_MAX_CHARS} znaków (limit komponentu QRCode)`)
              .fontSize(12)
              .fontColor(C_MUTED)
              .width('100%')
            if (ProofToken.fitsQr(this.token)) {
              QRCode(this.token)
                .width(240)
                .height(240)
                .color(C_TEXT)
                .backgroundColor('#FFFFFF')
            } else {
              Text('Token za długi na QR — skróć wyjaśnienie. Można go przesłać jako tekst.')
                .fontSize(13)
                .fontColor(C_BAD)
                .width('100%')
            }
            Button(this.showRaw ? 'Ukryj token' : 'Pokaż token (tekst)')
              .secondaryButton()
              .onClick(() => {
                this.showRaw = !this.showRaw;
              })
            if (this.showRaw) {
              Text(this.token)
                .fontSize(11)
                .fontFamily('monospace')
                .fontColor(C_TEXT)
                .copyOption(CopyOptions.LocalDevice)
                .width('100%')
            }
            Button('Wyślij do ubezpieczyciela (symulacja skanu QR)')
              .primaryButton()
              .onClick(() => {
                this.sendToInsurer();
              })
          }
          .cardStyle()
          .alignItems(HorizontalAlign.Center)
        }
      }
      .padding(16)
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  // ---------- zakładka: Ubezpieczyciel ----------

  @Builder
  insurerTab() {
    Scroll() {
      Column({ space: 12 }) {
        Text('Widok ubezpieczyciela (demo w tej samej aplikacji)')
          .fontSize(13)
          .fontColor(C_MUTED)
          .width('100%')

        Column({ space: 8 }) {
          this.sectionTitle('Zarejestrowane urządzenia', 'Ubezpieczyciel zna tylko klucze publiczne')
          if (this.registeredKeys.length === 0) {
            Text('Brak — klient rejestruje klucz w zakładce Raport')
              .fontSize(13)
              .fontColor(C_MUTED)
              .width('100%')
          }
          ForEach(this.registeredKeys, (k: DeviceKey) => {
            Column({ space: 2 }) {
              Text(`kid ${k.kid} · ${k.source === KeySource.HUKS ? 'klucz w HUKS' : 'klucz programowy'}` +
                (k.attested ? ' · atestowany' : ''))
                .fontSize(14)
                .fontColor(C_TEXT)
              Text(`${k.publicKeyB64.substring(0, 28)}…`)
                .fontSize(11)
                .fontFamily('monospace')
                .fontColor(C_MUTED)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }, (k: DeviceKey) => k.kid)
        }
        .cardStyle()

        Column({ space: 8 }) {
          this.sectionTitle('Żądanie raportu', 'Jednorazowe wyzwanie: chroni przed ponownym użyciem starego raportu')
          Text(`Aktualny nonce: ${this.insurerNonce}`)
            .fontSize(13)
            .fontFamily('monospace')
            .fontColor(C_TEXT)
            .width('100%')
          Button('Nowe żądanie (nowy nonce)')
            .secondaryButton()
            .onClick(() => {
              this.newInsurerRequest();
            })
        }
        .cardStyle()

        Column({ space: 8 }) {
          this.sectionTitle('Odebrany raport', 'Token z QR albo wklejony tekst PA1.…')
          TextArea({ text: this.inbox, placeholder: 'PA1.…' })
            .height(96)
            .fontSize(12)
            .onChange((value: string) => {
              this.inbox = value;
              this.verified = false;
            })
          Button(this.verifyBusy ? 'Weryfikuję…' : 'Weryfikuj podpis i treść')
            .primaryButton()
            .enabled(!this.verifyBusy && this.inbox.length > 0)
            .onClick(() => {
              this.verifyInbox();
            })
          Button('Symuluj manipulację: podnieś próg / podmień polisę')
            .dangerButton()
            .enabled(!this.verifyBusy && (this.inbox.length > 0 || this.token.length > 0))
            .onClick(() => {
              this.tamperAndVerify();
            })
        }
        .cardStyle()

        if (this.verified) {
          this.verificationCard()
        }

        if (this.decisionLog.length > 0) {
          Column({ space: 6 }) {
            this.sectionTitle('Dziennik decyzji', 'Każda decyzja ma ślad: automat albo konkretny człowiek')
            ForEach(this.decisionLog, (entry: string) => {
              Text(entry)
                .fontSize(12)
                .fontColor(C_TEXT)
                .width('100%')
            }, (entry: string, i: number) => `${i}|${entry}`)
          }
          .cardStyle()
        }
      }
      .padding(16)
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  @Builder
  verificationCard() {
    Column({ space: 8 }) {
      Text(this.verification.ok ? 'Raport autentyczny' : 'Raport odrzucony')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.verification.ok ? C_ACCENT : C_BAD)
        .backgroundColor(this.verification.ok ? C_ACCENT_SOFT : C_BAD_SOFT)
        .borderRadius(10)
        .padding(12)
        .width('100%')
      ForEach(this.verification.items, (c: CheckItem) => {
        Row({ space: 10 }) {
          Text(c.passed ? '✓' : '✗')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(c.passed ? C_ACCENT : C_BAD)
          Column({ space: 2 }) {
            Text(c.name)
              .fontSize(14)
              .fontColor(C_TEXT)
            Text(c.detail)
              .fontSize(12)
              .fontColor(C_MUTED)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (c: CheckItem) => `${c.name}|${c.passed}|${c.detail}`)

      if (this.verification.ok && this.vStatus() === 'OK') {
        Divider().color(C_LINE)
        Text(`Próg ${Labels.tierShort(this.vTier())} → przykładowa zniżka ${Labels.exampleDiscountPct(this.vTier())}%`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(C_TEXT)
          .width('100%')
        Text('Cennik należy do ubezpieczyciela, aplikacja dostarcza tylko dowód. Zmiana wyłącznie na korzyść klienta; ' +
          'klient może poprosić o przegląd przez człowieka.')
          .fontSize(12)
          .fontColor(C_MUTED)
          .width('100%')
      }

      if (this.verification.ok && this.vStatus() === 'REVIEW') {
        Divider().color(C_LINE)
        Text('Wymaga decyzji człowieka')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(C_WARN)
          .width('100%')
        ForEach(this.reviewRows(), (r: LabeledValue) => {
          this.kvRow(r.label, r.value)
        }, (r: LabeledValue) => `${r.label}=${r.value}`)
        if (!this.reviewDone) {
          Button('Zatwierdź próg wstępny')
            .primaryButton()
            .onClick(() => {
              this.decide(`zatwierdzono próg ${Labels.tierShort(this.vTier())}`);
            })
          Button('Poproś klienta o wyjaśnienie')
            .secondaryButton()
            .onClick(() => {
              this.decide('poproszono o wyjaśnienie podejrzanych dni');
            })
          Button('Odrzuć zniżkę w tym okresie (składka bez zmian)')
            .dangerButton()
            .onClick(() => {
              this.decide('zniżka nieprzyznana, składka bez zmian');
            })
        } else {
          Text('Decyzja zapisana w dzienniku poniżej.')
            .fontSize(12)
            .fontColor(C_MUTED)
            .width('100%')
        }
      }
    }
    .cardStyle()
  }
}
