import { common } from '@kit.AbilityKit';
import {
  ALL_HEALTH_SCOPES,
  EmptyHealthSource,
  HEALTH_MISSING,
  HealthConnection,
  HealthScope,
  HealthSimPayload,
  HealthSource,
  HealthStatus,
  withScopes
} from 'common';
import {
  HEALTH_SIM_ERROR_TEXT,
  HealthSimAnswer,
  HealthSimAnswerKind,
  HealthSimClient
} from '../platform/HealthSimClient';
import { HuaweiHealthSource } from '../platform/HuaweiHealthSource';
import { clearHealthSim, useHealthSim } from '../report/ServiceLocator';

// AppStorage keys the screens bind to. AddonSession.publish() is the only writer.
export const KEY_STATUS: string = 'fwSourceStatus';       // HealthStatus value
export const KEY_REFUSED: string = 'fwRefused';           // last answer on the authorization step was a refusal
export const KEY_WAS_CONNECTED: string = 'fwWasConnected'; // connected at least once since the app started
export const KEY_SCOPES_ON: string = 'fwScopesOn';        // number of data types allowed
export const KEY_LAST_SYNC: string = 'fwLastSync';        // text, NO_VALUE when unknown
export const KEY_REVISION: string = 'fwRevision';         // bumped on every change

// Shown wherever a value does not exist. Never replaced by zero or a made-up number.
export const NO_VALUE: string = '—';

// The one place that owns the health connection of the add-on. Screens call it and read AppStorage.
export class AddonSession {
  private static instance: AddonSession | null = null;

  private platform: HuaweiHealthSource = new HuaweiHealthSource();
  private connection: HealthConnection;
  private wasConnected: boolean = false;
  private revision: number = 0;
  // The data Health Sim sent for this connection attempt, held between the two consent steps. Null on the
  // built-in demo path.
  private pendingHealthSim: HealthSimPayload | null = null;
  // Why the built-in demo placeholder is shown instead of Health Sim's consent screen; empty when it is not.
  private fallbackNote: string = '';
  // Number of the latest request to Health Sim; an answer to an older or abandoned request is ignored.
  private askSeq: number = 0;

  private constructor() {
    // The adapter for HUAWEI Health is a stub in this build (UNAVAILABLE), so the connection runs on the
    // demo source. The demo source has no records until the demo data set (SyntheticHealthSource) is added.
    const inner: HealthSource = this.platform.status() === HealthStatus.CONNECTED
      ? this.platform
      : new EmptyHealthSource(HealthStatus.DEMO);
    this.connection = new HealthConnection(inner);
  }

  static shared(): AddonSession {
    if (AddonSession.instance === null) {
      AddonSession.instance = new AddonSession();
    }
    return AddonSession.instance;
  }

  // What the HUAWEI Health adapter itself reports, before any consent.
  platformStatus(): HealthStatus {
    return this.platform.status();
  }

  source(): HealthConnection {
    return this.connection;
  }

  /*
   * Step 1 of consent, asked of Health Sim: the separate app that stands in for HUAWEI Health on the
   * emulators shows its own consent screen. Returns the kind of its answer (HealthSimAnswerKind):
   *   OK             step 1 is granted and the data waits for step 2;
   *   REFUSED        step 1 is refused;
   *   NOT_INSTALLED, ERROR   nothing is recorded: the caller shows the built-in demo placeholder;
   *   STALE          the request was abandoned meanwhile (abandonHealthSim): nothing is recorded.
   * Never rejects. It may never resolve: when the user cancels the system's own question about opening
   * another app, the system reports nothing back, so the caller must offer a way out while it waits.
   */
  async askHealthSim(context: common.UIAbilityContext): Promise<string> {
    this.askSeq += 1;
    const seq: number = this.askSeq;
    const answer: HealthSimAnswer = await HealthSimClient.request(context, ALL_HEALTH_SCOPES);
    if (seq !== this.askSeq) {
      return HealthSimAnswerKind.STALE;
    }
    this.fallbackNote = '';
    if (answer.kind === HealthSimAnswerKind.OK && answer.payload !== null) {
      this.recordPlatformConsent(true);
      this.pendingHealthSim = answer.payload;
    } else if (answer.kind === HealthSimAnswerKind.REFUSED) {
      this.recordPlatformConsent(false);
    } else {
      this.pendingHealthSim = null;
      this.fallbackNote = answer.text;
    }
    return answer.kind;
  }

  // Gives up the request that is waiting for Health Sim: a late answer to it is ignored and the built-in
  // demo placeholder says why it is shown.
  abandonHealthSim(): void {
    this.askSeq += 1;
    this.pendingHealthSim = null;
    this.fallbackNote = HEALTH_SIM_ERROR_TEXT;
  }

  // One sentence for the placeholder: why Health Sim was not used. Empty when it was not asked.
  healthSimNote(): string {
    return this.fallbackNote;
  }

  // Step 1 of consent from the built-in demo placeholder (no Health Sim): the demo operator's answer.
  recordPlatformConsent(granted: boolean): void {
    this.pendingHealthSim = null;
    this.connection.recordPlatformConsent(granted);
    this.publish();
  }

  // Step 2 of consent: FairWear's own consent with the data types left switched on.
  confirmDataConsent(scopes: HealthScope[]): boolean {
    const ok: boolean = this.connection.confirmDataConsent(scopes);
    if (ok) {
      this.wasConnected = true;
      // The reports change their source before the screens hear about the new status: Health Sim's data
      // with the switched-off types removed, or the built-in demo histories when Health Sim was not used.
      const payload: HealthSimPayload | null = this.pendingHealthSim;
      if (payload !== null) {
        useHealthSim(withScopes(payload, scopes));
      } else {
        clearHealthSim();
      }
      this.pendingHealthSim = null;
    }
    this.publish();
    return ok;
  }

  // Withdraws both consents and forgets the data Health Sim sent. Connecting again asks Health Sim again.
  disconnect(): void {
    this.connection.disconnect();
    this.pendingHealthSim = null;
    clearHealthSim();
    this.publish();
  }

  // How many records the connection hands out for one data type; 0 when it is off or there are none.
  recordCount(scope: HealthScope): number {
    const c: HealthConnection = this.connection;
    if (scope === HealthScope.SLEEP) {
      return c.sleep(90).length;
    }
    if (scope === HealthScope.VO2MAX) {
      return c.vo2max(90).length;
    }
    if (scope === HealthScope.HRV) {
      return c.hrv(90).length;
    }
    if (scope === HealthScope.WORKOUTS) {
      return c.workouts(90).length;
    }
    let n: number = 0;
    const days = c.daily(90);
    for (let i = 0; i < days.length; i++) {
      let value: number = days[i].steps;
      if (scope === HealthScope.RESTING_HEART_RATE) {
        value = days[i].restingHeartRate;
      } else if (scope === HealthScope.ACTIVITY_MINUTES) {
        value = days[i].moderateMinutes;
      }
      if (value !== HEALTH_MISSING) {
        n++;
      }
    }
    return n;
  }

  totalRecordCount(): number {
    let n: number = 0;
    for (let i = 0; i < ALL_HEALTH_SCOPES.length; i++) {
      n += this.recordCount(ALL_HEALTH_SCOPES[i]);
    }
    return n;
  }

  publish(): void {
    this.revision++;
    AppStorage.setOrCreate<string>(KEY_STATUS, this.connection.status());
    AppStorage.setOrCreate<boolean>(KEY_REFUSED, this.connection.wasRefused());
    AppStorage.setOrCreate<boolean>(KEY_WAS_CONNECTED, this.wasConnected);
    AppStorage.setOrCreate<number>(KEY_SCOPES_ON, this.connection.enabledScopes().length);
    AppStorage.setOrCreate<string>(KEY_LAST_SYNC, AddonSession.syncText(this.connection.lastSyncMs()));
    AppStorage.setOrCreate<number>(KEY_REVISION, this.revision);
  }

  private static syncText(ms: number): string {
    if (ms === HEALTH_MISSING) {
      return NO_VALUE;
    }
    const d: Date = new Date(ms);
    const hh: string = d.getHours() < 10 ? '0' + d.getHours() : '' + d.getHours();
    const mm: string = d.getMinutes() < 10 ? '0' + d.getMinutes() : '' + d.getMinutes();
    return hh + ':' + mm;
  }
}
