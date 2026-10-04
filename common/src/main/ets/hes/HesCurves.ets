// Generic piecewise-linear scoring (specification section 5). The curves themselves are in HesModel.ets.
import { HesPoint } from './HesModel';

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
 * At or below the first point: the first score. At or above the last point: the last score. Between two
 * points: a straight line, so an exact point gives its exact score. The result is clamped to 0..100.
 * A value that is not a finite number, or an empty curve, gives no score (undefined), never NaN.
 */
export function piecewise(points: HesPoint[], x: number): number | undefined {
  if (points.length === 0 || !Number.isFinite(x)) {
    return undefined;
  }
  const first = points[0];
  if (x <= first.x) {
    return clampScore(first.y);
  }
  const last = points[points.length - 1];
  if (x >= last.x) {
    return clampScore(last.y);
  }
  for (let i = 0; i < points.length - 1; i++) {
    const a = points[i];
    const b = points[i + 1];
    if (x <= b.x) {
      if (b.x <= a.x) {
        return clampScore(b.y);
      }
      return clampScore(a.y + ((x - a.x) / (b.x - a.x)) * (b.y - a.y));
    }
  }
  return clampScore(last.y);
}
