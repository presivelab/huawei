/**
 * Scenario settings and access log, persisted with Preferences.
 * EntryAbility and AuthAbility run in the same process and share this file,
 * so FairWear always receives the scenario shown in the simulator.
 */
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { HsDataset } from '../healthsim/HsTypes';
import { HsPersonas } from '../healthsim/HsPersonas';
import { DEMO_ANCHOR_MS, HsGenerator } from '../healthsim/HsGenerator';

export const ANCHOR_DEMO: string = 'demo';
export const ANCHOR_LIVE: string = 'live';

export class ScenarioState {
  personaId: string = 'kasia';
  seed: number = 42;
  anchorMode: string = ANCHOR_DEMO;
  syncDelay: boolean = true;
  days: number = 30;
}

export class AccessEntry {
  requester: string = '';
  timeMs: number = 0;
  typeCount: number = 0;
  granted: boolean = false;
  datasetId: string = '';
}

const PREFS_NAME: string = 'healthsim';
const MAX_LOG: number = 6;

export class ScenarioStore {
  private prefs: preferences.Preferences | null = null;

  constructor(context: common.Context) {
    try {
      const options: preferences.Options = { name: PREFS_NAME };
      this.prefs = preferences.getPreferencesSync(context, options);
    } catch (e) {
      this.prefs = null;
    }
  }

  load(): ScenarioState {
    const s: ScenarioState = new ScenarioState();
    const p: preferences.Preferences | null = this.prefs;
    if (p === null) {
      return s;
    }
    try {
      s.personaId = p.getSync('personaId', s.personaId) as string;
      s.seed = p.getSync('seed', s.seed) as number;
      s.anchorMode = p.getSync('anchorMode', s.anchorMode) as string;
      s.syncDelay = p.getSync('syncDelay', s.syncDelay) as boolean;
      s.days = p.getSync('days', s.days) as number;
    } catch (e) {
      return new ScenarioState();
    }
    return s;
  }

  save(s: ScenarioState): void {
    const p: preferences.Preferences | null = this.prefs;
    if (p === null) {
      return;
    }
    try {
      p.putSync('personaId', s.personaId);
      p.putSync('seed', s.seed);
      p.putSync('anchorMode', s.anchorMode);
      p.putSync('syncDelay', s.syncDelay);
      p.putSync('days', s.days);
      p.flushSync();
    } catch (e) {
      // Settings simply do not persist; the current session still uses them.
    }
  }

  loadLog(): AccessEntry[] {
    const p: preferences.Preferences | null = this.prefs;
    if (p === null) {
      return [];
    }
    try {
      const text: string = p.getSync('accessLog', '[]') as string;
      return JSON.parse(text) as AccessEntry[];
    } catch (e) {
      return [];
    }
  }

  appendLog(entry: AccessEntry): void {
    const p: preferences.Preferences | null = this.prefs;
    if (p === null) {
      return;
    }
    const log: AccessEntry[] = this.loadLog();
    log.unshift(entry);
    while (log.length > MAX_LOG) {
      log.pop();
    }
    try {
      p.putSync('accessLog', JSON.stringify(log));
      p.flushSync();
    } catch (e) {
      // Log is best-effort.
    }
  }
}

/** Simulated "now" for a scenario. Demo mode is fixed so every run and both apps see the same data. */
export function anchorFor(s: ScenarioState): number {
  return s.anchorMode === ANCHOR_LIVE ? Date.now() : DEMO_ANCHOR_MS;
}

export function generateFor(s: ScenarioState): HsDataset {
  return HsGenerator.generate(HsPersonas.byId(s.personaId), s.seed, anchorFor(s), s.days);
}
