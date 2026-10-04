import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { LiveDayCollector } from '../logic/LiveDayCollector';

/*
 * Prawdziwe czujniki OpenHarmony (@ohos.sensor):
 *  - PEDOMETER       (uprawnienie ohos.permission.ACTIVITY_MOTION)
 *  - HEART_RATE      (uprawnienie ohos.permission.READ_HEALTH_DATA, tylko przy zgodzie na tętno)
 *  - WEAR_DETECTION  (czy zegarek jest na nadgarstku)
 * Odczyty trafiają wyłącznie do LiveDayCollector w pamięci; nic nie jest wysyłane.
 * Na emulatorze czujników zwykle nie ma - UI pokazuje to i oferuje symulator z tym samym collectorem.
 */

export class SensorAvailability {
  heartRate: boolean = false;
  pedometer: boolean = false;
  wear: boolean = false;
  listError: string = '';
  count: number = 0;

  anyUseful(): boolean {
    return this.heartRate || this.pedometer || this.wear;
  }
}

export class SensorSource {
  static readonly INTERVAL_NS: number = 1000000000;

  /** Wspólny dla prawdziwych czujników i symulatora w UI. */
  collector: LiveDayCollector = new LiveDayCollector();
  private hrOn: boolean = false;
  private stepsOn: boolean = false;
  private wearOn: boolean = false;
  errors: string[] = [];

  static async probe(): Promise<SensorAvailability> {
    const a = new SensorAvailability();
    try {
      const list = await sensor.getSensorList();
      a.count = list.length;
      for (const s of list) {
        if (s.sensorId === sensor.SensorId.HEART_RATE) {
          a.heartRate = true;
        } else if (s.sensorId === sensor.SensorId.PEDOMETER) {
          a.pedometer = true;
        } else if (s.sensorId === sensor.SensorId.WEAR_DETECTION) {
          a.wear = true;
        }
      }
    } catch (e) {
      const err = e as BusinessError;
      a.listError = `${err.code}: ${err.message}`;
    }
    return a;
  }

  isRunning(): boolean {
    return this.hrOn || this.stepsOn || this.wearOn;
  }

  /** Zwraca liczbę uruchomionych czujników; błędy trafiają do this.errors. */
  start(avail: SensorAvailability, useHeartRate: boolean): number {
    this.stop();
    this.errors = [];
    this.collector.reset();
    const opts: sensor.Options = { interval: SensorSource.INTERVAL_NS };

    if (avail.pedometer) {
      try {
        sensor.on(sensor.SensorId.PEDOMETER, (data: sensor.PedometerResponse) => {
          this.collector.addPedometer(data.steps, Date.now());
        }, opts);
        this.stepsOn = true;
      } catch (e) {
        this.errors.push(`Krokomierz: ${SensorSource.errText(e as BusinessError)}`);
      }
    }
    if (avail.heartRate && useHeartRate) {
      try {
        sensor.on(sensor.SensorId.HEART_RATE, (data: sensor.HeartRateResponse) => {
          this.collector.addHeartRate(data.heartRate, Date.now());
        }, opts);
        this.hrOn = true;
      } catch (e) {
        this.errors.push(`Tętno: ${SensorSource.errText(e as BusinessError)}`);
      }
    }
    if (avail.wear) {
      try {
        sensor.on(sensor.SensorId.WEAR_DETECTION, (data: sensor.WearDetectionResponse) => {
          this.collector.setWorn(data.value);
        }, opts);
        this.wearOn = true;
      } catch (e) {
        this.errors.push(`Wykrywanie noszenia: ${SensorSource.errText(e as BusinessError)}`);
      }
    }
    return (this.stepsOn ? 1 : 0) + (this.hrOn ? 1 : 0) + (this.wearOn ? 1 : 0);
  }

  stop(): void {
    if (this.stepsOn) {
      try {
        sensor.off(sensor.SensorId.PEDOMETER);
      } catch (e) {
        this.errors.push('Krokomierz: nie udało się wyłączyć');
      }
      this.stepsOn = false;
    }
    if (this.hrOn) {
      try {
        sensor.off(sensor.SensorId.HEART_RATE);
      } catch (e) {
        this.errors.push('Tętno: nie udało się wyłączyć');
      }
      this.hrOn = false;
    }
    if (this.wearOn) {
      try {
        sensor.off(sensor.SensorId.WEAR_DETECTION);
      } catch (e) {
        this.errors.push('Wykrywanie noszenia: nie udało się wyłączyć');
      }
      this.wearOn = false;
    }
  }

  private static errText(err: BusinessError): string {
    if (err.code === 201) {
      return 'brak uprawnienia (201) — nadaj je w oknie systemowym';
    }
    return `${err.code}: ${err.message}`;
  }
}
