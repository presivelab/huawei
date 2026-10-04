/**
 * Consent screen shown to the user when another app (FairWear) asks for data.
 * The user picks data types; only those are encoded into the result payload.
 */
import { common, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HsCodec, HsWantKeys } from '../healthsim/HsCodec';
import { HsPersonas } from '../healthsim/HsPersonas';
import {
  HS_RESULT_DENIED,
  HS_RESULT_ERROR,
  HS_RESULT_GRANTED,
  HsDataset,
  HsDataType,
  HsPayload
} from '../healthsim/HsTypes';
import { SimBanner } from '../components/Common';
import { AuthRequest } from '../model/AuthRequest';
import { AccessEntry, generateFor, ScenarioState, ScenarioStore } from '../model/ScenarioStore';

const DOMAIN: number = 0x0000;
const TAG: string = 'HealthSimAuth';

@Entry
@Component
struct AuthPage {
  @StorageLink('healthsim.authRequest') @Watch('onRequestChange') request: AuthRequest = new AuthRequest();
  @State checks: boolean[] = [];
  @State busy: boolean = false;
  @State showNoneSelected: boolean = false;
  @State personaName: string = '';
  @State datasetId: string = '';
  private store: ScenarioStore | null = null;

  aboutToAppear(): void {
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.store = new ScenarioStore(ctx);
    this.onRequestChange();
  }

  onBackPress(): boolean {
    this.finish(false);
    return true;
  }

  onRequestChange(): void {
    this.checks = this.request.types.map((t: string): boolean => true);
    this.busy = false;
    this.showNoneSelected = false;
    const s: ScenarioState = this.scenarioForRequest();
    this.personaName = HsPersonas.byId(s.personaId).name;
    this.datasetId = HsCodec.datasetId(generateFor(s));
  }

  private scenarioForRequest(): ScenarioState {
    const s: ScenarioState = this.store !== null ? this.store.load() : new ScenarioState();
    s.days = this.request.days;
    return s;
  }

  private selectedTypes(): string[] {
    const out: string[] = [];
    for (let i = 0; i < this.request.types.length; i++) {
      if (i < this.checks.length && this.checks[i]) {
        out.push(this.request.types[i]);
      }
    }
    return out;
  }

  private setCheck(index: number, on: boolean): void {
    const next: boolean[] = this.checks.slice(0);
    next[index] = on;
    this.checks = next;
    this.showNoneSelected = false;
  }

  private finish(granted: boolean): void {
    if (this.busy) {
      return;
    }
    const types: string[] = this.selectedTypes();
    if (granted && types.length === 0) {
      this.showNoneSelected = true;
      return;
    }
    this.busy = true;
    const params: Record<string, Object> = {};
    let resultCode: number = HS_RESULT_DENIED;
    params[HsWantKeys.STATUS] = 'denied';
    let id: string = '';
    if (granted) {
      try {
        const s: ScenarioState = this.scenarioForRequest();
        const ds: HsDataset = generateFor(s);
        const payload: HsPayload = HsCodec.encode(ds, types, s.syncDelay);
        id = payload.datasetId;
        params[HsWantKeys.PAYLOAD] = HsCodec.toJson(payload);
        params[HsWantKeys.STATUS] = 'granted';
        resultCode = HS_RESULT_GRANTED;
      } catch (e) {
        params[HsWantKeys.STATUS] = 'error';
        resultCode = HS_RESULT_ERROR;
        hilog.error(DOMAIN, TAG, 'Encoding failed: %{public}s', JSON.stringify(e));
      }
    }
    if (this.store !== null) {
      const entry: AccessEntry = new AccessEntry();
      entry.requester = this.request.requester;
      entry.timeMs = Date.now();
      entry.typeCount = granted ? types.length : 0;
      entry.granted = resultCode === HS_RESULT_GRANTED;
      entry.datasetId = id;
      this.store.appendLog(entry);
    }
    const want: Want = { parameters: params };
    const result: common.AbilityResult = { resultCode: resultCode, want: want };
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ctx.terminateSelfWithResult(result).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'terminateSelfWithResult failed: %{public}s', JSON.stringify(err));
      this.busy = false;
    });
  }

  private typeLabel(t: string): Resource {
    if (t === HsDataType.STEPS) {
      return $r('app.string.type_steps');
    }
    if (t === HsDataType.HEART_RATE) {
      return $r('app.string.type_hr');
    }
    if (t === HsDataType.RESTING_HR) {
      return $r('app.string.type_rhr');
    }
    if (t === HsDataType.SLEEP_FRAGMENT) {
      return $r('app.string.type_sleep');
    }
    if (t === HsDataType.SPO2) {
      return $r('app.string.type_spo2');
    }
    if (t === HsDataType.SKIN_TEMP) {
      return $r('app.string.type_skin');
    }
    if (t === HsDataType.STRESS) {
      return $r('app.string.type_stress');
    }
    return $r('app.string.type_vo2');
  }

  private isChecked(index: number): boolean {
    return index < this.checks.length ? this.checks[index] : false;
  }

  build() {
    Column() {
      SimBanner()
      Scroll() {
        Column({ space: 16 }) {
          Text('HS')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.on_accent'))
            .textAlign(TextAlign.Center)
            .width(56)
            .height(56)
            .borderRadius(16)
            .backgroundColor($r('app.color.accent'))
            .margin({ top: 24 })
          Text($r('app.string.auth_title', this.request.requester))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .textAlign(TextAlign.Center)
          Text($r('app.string.auth_sub', this.personaName, String(this.request.days)))
            .fontSize(13)
            .fontColor($r('app.color.muted'))
            .textAlign(TextAlign.Center)
          if (this.request.callerBundle.length > 0) {
            Text(this.request.callerBundle)
              .fontSize(11)
              .fontFamily('monospace')
              .fontColor($r('app.color.muted'))
          }

          Column() {
            ForEach(this.request.types, (t: string, index: number) => {
              Row() {
                Text(this.typeLabel(t))
                  .fontSize(15)
                  .fontColor($r('app.color.ink'))
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Checkbox, isOn: this.isChecked(index) })
                  .selectedColor($r('app.color.accent'))
                  .onChange((isOn: boolean) => {
                    this.setCheck(index, isOn);
                  })
              }
              .width('100%')
              .height(48)
            }, (t: string) => t + '-' + this.request.receivedAt)
          }
          .width('100%')
          .padding({ left: 16, right: 12 })
          .borderRadius(16)
          .backgroundColor($r('app.color.surface'))

          Text($r('app.string.auth_note'))
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('app.color.muted'))
          Text($r('app.string.data_id', this.datasetId))
            .fontSize(12)
            .fontFamily('monospace')
            .fontColor($r('app.color.accent'))
          if (this.showNoneSelected) {
            Text($r('app.string.auth_none'))
              .fontSize(12)
              .fontColor($r('app.color.sick_text'))
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      Row({ space: 12 }) {
        Button($r('app.string.auth_deny'))
          .layoutWeight(1)
          .height(44)
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.empty'))
          .enabled(!this.busy)
          .onClick(() => {
            this.finish(false);
          })
        Button($r('app.string.auth_allow'))
          .layoutWeight(1)
          .height(44)
          .fontColor($r('app.color.on_accent'))
          .backgroundColor($r('app.color.accent'))
          .enabled(!this.busy)
          .onClick(() => {
            this.finish(true);
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page'))
  }
}
