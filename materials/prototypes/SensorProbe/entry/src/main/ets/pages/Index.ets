import { sensor } from '@kit.SensorServiceKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'SensorProbe';
const PERMISSIONS: Permissions[] = ['ohos.permission.READ_HEALTH_DATA', 'ohos.permission.ACTIVITY_MOTION'];
const INTERVAL_NS = 1000000000;

@Entry
@Component
struct Index {
  @State heartRate: number = -1;
  @State steps: number = -1;
  @State heartRateEvents: number = 0;
  @State stepEvents: number = 0;
  @State status: string = 'starting';

  aboutToAppear(): void {
    this.start();
  }

  aboutToDisappear(): void {
    this.unsubscribe(sensor.SensorId.HEART_RATE);
    this.unsubscribe(sensor.SensorId.PEDOMETER);
  }

  private async start(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, PERMISSIONS);
      hilog.info(DOMAIN, TAG, 'permissions: %{public}s', JSON.stringify(result.authResults));
      this.status = result.authResults.every((code) => code === 0) ? 'granted' : 'denied';
    } catch (err) {
      this.status = `permission error ${(err as BusinessError).code}`;
      hilog.error(DOMAIN, TAG, 'requestPermissions failed: %{public}s', JSON.stringify(err));
    }
    this.logSensorList();
    this.subscribeHeartRate();
    this.subscribePedometer();
  }

  private logSensorList(): void {
    try {
      const ids = sensor.getSensorListSync().map((item) => `${item.sensorId}:${item.sensorName}`);
      hilog.info(DOMAIN, TAG, 'sensors: %{public}s', ids.join(', '));
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'getSensorList failed: %{public}s', JSON.stringify(err));
    }
  }

  private subscribeHeartRate(): void {
    try {
      sensor.on(sensor.SensorId.HEART_RATE, (data: sensor.HeartRateResponse) => {
        this.heartRate = data.heartRate;
        this.heartRateEvents++;
        hilog.info(DOMAIN, TAG, 'heartRate=%{public}d', data.heartRate);
      }, { interval: INTERVAL_NS });
      hilog.info(DOMAIN, TAG, 'heart rate subscribed');
    } catch (err) {
      this.status = `HR error ${(err as BusinessError).code}`;
      hilog.error(DOMAIN, TAG, 'heart rate subscribe failed: %{public}s', JSON.stringify(err));
    }
  }

  private subscribePedometer(): void {
    try {
      sensor.on(sensor.SensorId.PEDOMETER, (data: sensor.PedometerResponse) => {
        this.steps = data.steps;
        this.stepEvents++;
        hilog.info(DOMAIN, TAG, 'steps=%{public}d', data.steps);
      }, { interval: INTERVAL_NS });
      hilog.info(DOMAIN, TAG, 'pedometer subscribed');
    } catch (err) {
      this.status = `steps error ${(err as BusinessError).code}`;
      hilog.error(DOMAIN, TAG, 'pedometer subscribe failed: %{public}s', JSON.stringify(err));
    }
  }

  private unsubscribe(id: sensor.SensorId.HEART_RATE | sensor.SensorId.PEDOMETER): void {
    try {
      if (id === sensor.SensorId.HEART_RATE) {
        sensor.off(sensor.SensorId.HEART_RATE);
      } else {
        sensor.off(sensor.SensorId.PEDOMETER);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'unsubscribe failed: %{public}s', JSON.stringify(err));
    }
  }

  build() {
    Column({ space: 6 }) {
      Text('SensorProbe')
        .fontSize(14)
        .fontColor('#99FFFFFF')
      Text(this.heartRate < 0 ? '-- bpm' : `${this.heartRate} bpm`)
        .fontSize(44)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FF5A3C')
      Text(this.steps < 0 ? '-- steps' : `${this.steps} steps`)
        .fontSize(28)
        .fontColor(Color.White)
      Text(`HR events ${this.heartRateEvents} · step events ${this.stepEvents}`)
        .fontSize(12)
        .fontColor('#99FFFFFF')
      Text(this.status)
        .fontSize(12)
        .fontColor('#99FFFFFF')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.Black)
  }
}
