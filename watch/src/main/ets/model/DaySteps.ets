// Today's steps from the pedometer's running counter. Pure logic: no sensor or storage imports.
// The sensor reports a counter that keeps growing across days, so today = raw - first raw of the day.

// Returned instead of a step count before the first reading of the day. Never zero.
export const NO_STEPS: number = -1;

export class DayStepsState {
  dayKey: string = '';
  // Raw counter value that counts as zero for today; NO_STEPS until the first reading of the day.
  baseline: number = NO_STEPS;
  // Steps counted today before the counter last dropped.
  carried: number = 0;
  lastRaw: number = NO_STEPS;
}

export class DaySteps {
  private data: DayStepsState = new DayStepsState();

  // Feed one raw counter reading. Returns true when the stored state changed.
  onRaw(dayKey: string, raw: number): boolean {
    const data = this.data;
    if (raw < 0) {
      return false;
    }
    if (data.dayKey !== dayKey || data.baseline === NO_STEPS) {
      // First reading of the day: it becomes today's zero.
      data.dayKey = dayKey;
      data.baseline = raw;
      data.carried = 0;
      data.lastRaw = raw;
      return true;
    }
    if (raw === data.lastRaw) {
      return false;
    }
    if (raw < data.lastRaw) {
      // The counter dropped (restart): keep what was counted and re-base on the new value.
      data.carried += data.lastRaw - data.baseline;
      data.baseline = raw;
    }
    data.lastRaw = raw;
    return true;
  }

  // Steps today, or NO_STEPS when there has been no reading on this day.
  today(dayKey: string): number {
    const data = this.data;
    if (data.dayKey !== dayKey || data.baseline === NO_STEPS) {
      return NO_STEPS;
    }
    return data.carried + (data.lastRaw - data.baseline);
  }

  lastRaw(): number {
    return this.data.lastRaw;
  }

  save(): string {
    return JSON.stringify(this.data);
  }

  // Restores a saved state; anything that does not look like one is ignored.
  restore(json: string): void {
    if (json.length === 0) {
      return;
    }
    try {
      const saved = JSON.parse(json) as DayStepsState;
      if (typeof saved.dayKey === 'string' && typeof saved.baseline === 'number' &&
        typeof saved.carried === 'number' && typeof saved.lastRaw === 'number') {
        const data = new DayStepsState();
        data.dayKey = saved.dayKey;
        data.baseline = saved.baseline;
        data.carried = saved.carried;
        data.lastRaw = saved.lastRaw;
        this.data = data;
      }
    } catch (err) {
      this.data = new DayStepsState();
    }
  }
}
