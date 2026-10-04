// Generic piecewise-linear scoring (specification sections 5 and 13).
import { HesPoint } from './HesTypes';

const SCORE_MIN: number = 0;
const SCORE_MAX: number = 100;

function clampScore(score: number): number {
  if (score < SCORE_MIN) {
    return SCORE_MIN;
  }
  if (score > SCORE_MAX) {
    return SCORE_MAX;
  }
  return score;
}

/**
 * Score of a raw value on a curve of points with rising x.
 * Below the first point: the first score. Above the last point: the last score. Between two points:
 * a straight line. Boundaries are inclusive, the result is clamped to 0..100.
 */
export function piecewiseScore(value: number, points: HesPoint[]): number {
  if (points.length === 0) {
    throw new Error('Invalid scoring curve');
  }
  const first = points[0];
  if (value <= first.x) {
    return clampScore(first.y);
  }
  const last = points[points.length - 1];
  if (value >= last.x) {
    return clampScore(last.y);
  }
  for (let i = 0; i < points.length - 1; i++) {
    const a = points[i];
    const b = points[i + 1];
    if (value >= a.x && value <= b.x) {
      const t = (value - a.x) / (b.x - a.x);
      return clampScore(a.y + t * (b.y - a.y));
    }
  }
  throw new Error('Invalid scoring curve');
}
