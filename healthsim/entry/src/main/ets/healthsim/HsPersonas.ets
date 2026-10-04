/**
 * Demo personas. Knobs follow WKLEJKA_MOCKUP_HUAWEI_HEALTH (HH-3):
 * stepsMean, wearHoursMean, chargeEveryDays, sick episodes,
 * selectiveRemovalAroundSick, padSlotsPerDay, tz.
 *
 * Values are a starting point. In FairWear, align them with the existing
 * personas and their target tiers; do not change a persona's target tier.
 */

export class HsEpisode {
  /** First sick day, counted back from the anchor day (anchor day = 0). */
  startDaysAgo: number = 0;
  lengthDays: number = 0;

  constructor(startDaysAgo: number, lengthDays: number) {
    this.startDaysAgo = startDaysAgo;
    this.lengthDays = lengthDays;
  }
}

export class HsPersona {
  id: string = '';
  name: string = '';
  stepsMean: number = 8000;
  wearHoursMean: number = 20;
  chargeEveryDays: number = 2;
  chargeHour: number = 19;
  restingHrBase: number = 60;
  vo2maxBase: number = 40;
  tzOffsetMin: number = 120;
  sickEpisodes: HsEpisode[] = [];
  /** Worn normally on the first 2 sick days, then mostly off until the day after the episode. */
  selectiveRemovalAroundSick: boolean = false;
  /** Evening slots with high steps and no heart-rate rise (phone shaking, step padding). */
  padSlotsPerDay: number = 0;
  /** Tier FairWear is expected to compute; informational only. */
  expectedTier: string = '';

  constructor(id: string, name: string) {
    this.id = id;
    this.name = name;
  }
}

function makeAnia(): HsPersona {
  const p: HsPersona = new HsPersona('ania', 'Ania');
  p.stepsMean = 10500;
  p.wearHoursMean = 22.5;
  p.chargeEveryDays = 3;
  p.chargeHour = 18;
  p.restingHrBase = 56;
  p.vo2maxBase = 44;
  p.tzOffsetMin = 120;
  p.expectedTier = 'A';
  return p;
}

function makeKasia(): HsPersona {
  const p: HsPersona = new HsPersona('kasia', 'Kasia');
  p.stepsMean = 7600;
  p.wearHoursMean = 19.5;
  p.chargeEveryDays = 2;
  p.chargeHour = 19;
  p.restingHrBase = 62;
  p.vo2maxBase = 38.5;
  p.tzOffsetMin = 120;
  p.sickEpisodes = [new HsEpisode(12, 3)];
  p.expectedTier = 'B';
  return p;
}

function makeMarek(): HsPersona {
  const p: HsPersona = new HsPersona('marek', 'Marek');
  p.stepsMean = 7800;
  // Near-continuous wearer on normal days, so his 30-day wear total matches Kasia's.
  p.wearHoursMean = 23;
  p.chargeEveryDays = 2;
  p.chargeHour = 19;
  p.restingHrBase = 63;
  p.vo2maxBase = 40;
  p.tzOffsetMin = 120;
  p.sickEpisodes = [new HsEpisode(21, 4), new HsEpisode(9, 4)];
  p.selectiveRemovalAroundSick = true;
  p.expectedTier = 'C';
  return p;
}

function makeWei(): HsPersona {
  const p: HsPersona = new HsPersona('wei', 'Wei');
  // Honest steps; padding adds about 2,200 a day on top.
  p.stepsMean = 5000;
  p.wearHoursMean = 20.5;
  p.chargeEveryDays = 2;
  p.chargeHour = 20;
  p.restingHrBase = 60;
  p.vo2maxBase = 41;
  p.tzOffsetMin = 480;
  p.padSlotsPerDay = 6;
  p.expectedTier = 'C';
  return p;
}

export class HsPersonas {
  static all(): HsPersona[] {
    return [makeAnia(), makeKasia(), makeMarek(), makeWei()];
  }

  static byId(id: string): HsPersona {
    const list: HsPersona[] = HsPersonas.all();
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return list[i];
      }
    }
    return list[0];
  }
}
