// The code lines the Watch Link tour shows must exist verbatim in the repository, and the tests it names
// must exist. Reads repository files, so it runs only under Node (not part of List.test.ets).
import { describe, it, expect } from '@ohos/hypium';
import { readRepoText } from '@fairwear/node-ports';
import { CODE_ELLIPSIS, TOUR_STEPS } from '../main/ets/present/TourContent';

function trimmedLines(text: string): string[] {
  const out: string[] = [];
  const lines = text.split('\n');
  for (let i = 0; i < lines.length; i++) {
    out.push(lines[i].replace('\r', '').trim());
  }
  return out;
}

export default function tourSnippetsTest() {
  describe('TourSnippets', () => {
    it('every code line on the tour exists verbatim in its file', 0, () => {
      for (let s = 0; s < TOUR_STEPS.length; s++) {
        const step = TOUR_STEPS[s];
        const text = readRepoText(step.file);
        expect(text !== null).assertTrue();
        if (text === null) {
          continue;
        }
        const source = trimmedLines(text);
        for (let i = 0; i < step.code.length; i++) {
          const line = step.code[i].trim();
          if (step.code[i] === CODE_ELLIPSIS || line.length === 0) {
            continue;
          }
          if (source.indexOf(line) < 0) {
            expect(`${step.file}: ${line}`).assertEqual('a line that exists in the file');
          }
        }
      }
    });

    it('every test the tour names exists', 0, () => {
      for (let s = 0; s < TOUR_STEPS.length; s++) {
        const step = TOUR_STEPS[s];
        if (step.testFile.length === 0) {
          continue;
        }
        const text = readRepoText(step.testFile);
        expect(text !== null).assertTrue();
        for (let i = 0; i < step.provedBy.length && text !== null; i++) {
          if (text.indexOf(`'${step.provedBy[i]}'`) < 0) {
            expect(`${step.testFile}: ${step.provedBy[i]}`).assertEqual('a test that exists');
          }
        }
      }
    });
  });
}
