import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/*
 * Visit notes on the watch: record the conversation with the doctor, for the patient's own notes.
 *
 *   Idle       "Record visit notes"
 *   Consent    "Ask your doctor: OK to record for your personal notes?"   Doctor agreed / Cancel
 *   Recording  a dot, the time, "Stays on this watch", Stop
 *   Saved      "Saved. Notes appear on your phone (demo)"
 *
 * Nothing is recorded before the doctor agreed. The sound is written to a file in the app sandbox of the
 * watch and is not sent anywhere: there is no transfer to the phone in this build, and the notes on the
 * phone come from a demo transcript. Where the watch has no audio capture, or the microphone permission
 * is refused, the screen runs as "Demo recording" and says so: the timer runs and no sound is captured.
 */

const DOMAIN = 0x0000;
const TAG = 'FairWear';
const TICK_MS = 1000;
const MICROPHONE: Permissions[] = ['ohos.permission.MICROPHONE'];
const CAPTURE_SYSCAP = 'SystemCapability.Multimedia.Audio.Capturer';
const RECORDINGS_DIR = 'visit-notes';

const STAGE_IDLE = 'idle';
const STAGE_CONSENT = 'consent';
const STAGE_RECORDING = 'recording';
const STAGE_SAVED = 'saved';

const TEXT_TITLE = 'Visit notes';
const TEXT_RECORD = 'Record visit notes';
const TEXT_IDLE_NOTE = 'For your own notes.\nNever part of a claim.';
const TEXT_ASK = 'Ask your doctor:\nOK to record for your\npersonal notes?';
const TEXT_AGREED = 'Doctor agreed';
const TEXT_CANCEL = 'Cancel';
const TEXT_STAYS = 'Stays on this watch';
const TEXT_DEMO_RECORDING = 'Demo recording';
const TEXT_STOP = 'Stop';
const TEXT_SAVED = 'Saved. Notes appear\non your phone (demo)';
const TEXT_SAVED_DEMO = 'Demo recording: no sound was kept';
const TEXT_DONE = 'Done';

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

// 75 seconds as "01:15".
function clockText(seconds: number): string {
  return `${pad2(Math.floor(seconds / 60))}:${pad2(seconds % 60)}`;
}

@Entry
@Component
struct VisitRecord {
  @State stage: string = STAGE_IDLE;
  @State seconds: number = 0;
  // True while the timer runs without the microphone: no capture on this device, or no permission.
  @State demoMode: boolean = false;
  @State busy: boolean = false;
  private timer: number = -1;
  private capturer: audio.AudioCapturer | null = null;
  private file: fileIo.File | null = null;
  private written: number = 0;

  aboutToDisappear(): void {
    this.stopTimer();
    this.closeCapture();
  }

  private startTimer(): void {
    this.seconds = 0;
    this.timer = setInterval(() => {
      this.seconds += 1;
    }, TICK_MS);
  }

  private stopTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  // The doctor agreed: ask for the microphone and start. Any failure on the way is the demo mode.
  private async begin(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const real = await this.openCapture();
    this.demoMode = !real;
    this.stage = STAGE_RECORDING;
    this.startTimer();
    this.busy = false;
  }

  private async openCapture(): Promise<boolean> {
    if (!canIUse(CAPTURE_SYSCAP)) {
      return false;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const granted = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, MICROPHONE);
      if (granted.authResults.length === 0 || granted.authResults[0] !== 0) {
        return false;
      }
      const dir = `${context.filesDir}/${RECORDINGS_DIR}`;
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir);
      }
      const file = fileIo.openSync(`${dir}/visit-${Date.now()}.pcm`,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      const options: audio.AudioCapturerOptions = {
        streamInfo: {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        },
        capturerInfo: {
          source: audio.SourceType.SOURCE_TYPE_MIC,
          capturerFlags: 0
        }
      };
      const capturer = await audio.createAudioCapturer(options);
      this.file = file;
      this.written = 0;
      capturer.on('readData', (buffer: ArrayBuffer): void => {
        const target = this.file;
        if (target !== null) {
          fileIo.writeSync(target.fd, buffer, { offset: this.written, length: buffer.byteLength });
          this.written += buffer.byteLength;
        }
      });
      await capturer.start();
      this.capturer = capturer;
      return true;
    } catch (e) {
      // Counters only in the log: nothing about the recording itself.
      hilog.info(DOMAIN, TAG, 'visit record: capture unavailable, demo mode');
      this.closeCapture();
      return false;
    }
  }

  private closeCapture(): void {
    const capturer = this.capturer;
    this.capturer = null;
    if (capturer !== null) {
      capturer.stop().then((): Promise<void> => capturer.release()).catch((): void => {
      });
    }
    const file = this.file;
    this.file = null;
    if (file !== null) {
      try {
        fileIo.closeSync(file);
      } catch (e) {
        // Already closed.
      }
    }
  }

  private finish(): void {
    this.stopTimer();
    this.closeCapture();
    this.stage = STAGE_SAVED;
  }

  @Builder
  action(label: string, strong: boolean, tap: () => void) {
    Button(label, { type: ButtonType.Capsule })
      .width('100%')
      .height(40)
      .fontSize($r('app.float.button_font_size'))
      .labelStyle({ maxLines: 1, minFontSize: 8, maxFontSize: $r('app.float.button_font_size') })
      .padding({ left: 6, right: 6 })
      .fontColor(strong ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
      .backgroundColor(strong ? $r('sys.color.comp_background_emphasize') : $r('sys.color.comp_background_secondary'))
      .onClick(() => {
        tap();
      })
  }

  @Builder
  note(text: string, color: ResourceColor) {
    Text(text)
      .fontSize($r('app.float.note_font_size'))
      .fontColor(color)
      .textAlign(TextAlign.Center)
  }

  build() {
    Column({ space: 8 }) {
      if (this.stage === STAGE_IDLE) {
        Text(TEXT_TITLE)
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        this.action(TEXT_RECORD, true, (): void => {
          this.stage = STAGE_CONSENT;
        })
        this.note(TEXT_IDLE_NOTE, $r('sys.color.font_secondary'))
      } else if (this.stage === STAGE_CONSENT) {
        Text(TEXT_ASK)
          .fontSize($r('app.float.button_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .textAlign(TextAlign.Center)
          .id('fw_visit_ask')
        this.action(TEXT_AGREED, true, (): void => {
          this.begin();
        })
        this.action(TEXT_CANCEL, false, (): void => {
          this.stage = STAGE_IDLE;
        })
      } else if (this.stage === STAGE_RECORDING) {
        Row({ space: 8 }) {
          Circle()
            .width(12)
            .height(12)
            .fill($r('sys.color.warning'))
          Text(clockText(this.seconds))
            .fontSize($r('app.float.code_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .id('fw_visit_clock')
        }
        .alignItems(VerticalAlign.Center)

        this.note(TEXT_STAYS, $r('sys.color.font_secondary'))
        if (this.demoMode) {
          Text(TEXT_DEMO_RECORDING)
            .fontSize($r('app.float.note_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.warning'))
            .id('fw_visit_demo_mode')
        }
        this.action(TEXT_STOP, false, (): void => {
          this.finish();
        })
      } else {
        Text(TEXT_SAVED)
          .fontSize($r('app.float.button_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .textAlign(TextAlign.Center)
          .id('fw_visit_saved')
        if (this.demoMode) {
          this.note(TEXT_SAVED_DEMO, $r('sys.color.warning'))
        } else {
          this.note(`${clockText(this.seconds)} · ${TEXT_STAYS.toLowerCase()}`, $r('sys.color.font_secondary'))
        }
        this.action(TEXT_DONE, false, (): void => {
          this.stage = STAGE_IDLE;
        })
      }
    }
    .width('100%')
    .height('100%')
    // The round screen: keep everything inside the safe circle.
    .padding({ left: 34, right: 34, top: 30, bottom: 30 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}
