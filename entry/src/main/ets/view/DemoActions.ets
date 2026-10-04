import { withoutAppealsOf } from 'common';
import { closeSelectedDay, resetSelected, selectedPersonaId, setSelectedLive } from '../report/ServiceLocator';
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
export function demoCloseDay(): void {
  closeSelectedDay();
}

// Returns the persona on screen to its starting history and forgets the appeals sent for it.
export function demoReset(): void {
  const appeals: string[] = AppStorage.get<string[]>(KEY_APPEALS) ?? [];
  AppStorage.setOrCreate<string[]>(KEY_APPEALS, withoutAppealsOf(appeals, selectedPersonaId()));
  resetSelected();
}
