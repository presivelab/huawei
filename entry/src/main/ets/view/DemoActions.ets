import { withoutAppealsOf } from 'common';
import { selectedPersonaId, selectedReport, setSelectedLive } from '../report/ServiceLocator';
import { KEY_APPEALS } from './EvidenceDayData';

/*
 * What the demo controls of the Report tab do. The screens call these three functions and nothing else,
 * so the service behind them can change without touching a screen.
 */

// The live readings of the persona on screen. Shown, never scored.
export function demoSetLive(hr: number, steps: number): void {
  setSelectedLive(hr, steps);
}

// Closes the running day of the persona on screen: it becomes a completed day and the score is
// calculated again.
// TODO(G1): call closeSelectedDay() from ServiceLocator once the engine-backed service is merged. The
// preview service has no days to close, so until then the report is only read again.
export function demoCloseDay(): void {
  const live = selectedReport().live;
  setSelectedLive(live.hr, live.steps);
}

// Returns the persona on screen to its starting month and forgets the appeals sent for it.
// TODO(G1): call resetSelected() from ServiceLocator once the engine-backed service is merged.
export function demoReset(): void {
  const appeals: string[] = AppStorage.get<string[]>(KEY_APPEALS) ?? [];
  AppStorage.setOrCreate<string[]>(KEY_APPEALS, withoutAppealsOf(appeals, selectedPersonaId()));
  const live = selectedReport().live;
  setSelectedLive(live.hr, live.steps);
}
