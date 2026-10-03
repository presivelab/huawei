import { UNKNOWN } from '../model/HealthEngine';

export const MOVE_COLOR = '#F34A29';
export const EXERCISE_COLOR = '#FBCF26';
export const STAND_COLOR = '#30ADFF';
export const MOVE_TRACK = '#4D1E12';
export const EXERCISE_TRACK = '#4A3D10';
export const STAND_TRACK = '#27394A';
export const HEART_COLOR = '#FF3B5C';
export const STEPS_COLOR = '#63D66B';
export const WORN_COLOR = '#63D66B';
export const TEXT_SECONDARY = '#99FFFFFF';
export const TEXT_FAINT = '#66FFFFFF';
export const CARD_FILL = '#1FFFFFFF';
export const HAIRLINE = '#33FFFFFF';
export const NO_VALUE = '--';

export const RINGS_BACKGROUND: [ResourceColor, number][] = [['#3A1800', 0], ['#120500', 1]];
export const ACTIVITY_BACKGROUND: [ResourceColor, number][] = [['#632800', 0], ['#000000', 1]];
export const HEART_BACKGROUND: [ResourceColor, number][] = [['#4A0012', 0], ['#1B040A', 1]];
export const SYSTEM_BACKGROUND: [ResourceColor, number][] = [['#0A1730', 0], ['#02050C', 1]];

export function grouped(value: number): string {
  return value.toString().replace(new RegExp('\\B(?=(\\d{3})+(?!\\d))', 'g'), ',');
}

export function shown(value: number): string {
  return value === UNKNOWN ? NO_VALUE : grouped(value);
}

// Share of a goal for a ring; an unknown value draws as an empty ring.
export function share(value: number, goal: number): number {
  return value === UNKNOWN ? 0 : value / goal;
}
