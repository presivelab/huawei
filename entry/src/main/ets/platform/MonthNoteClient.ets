import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { MONTH_NOTE_URL, monthNoteText } from 'common';

/*
 * Sends the month-note summary to the FairWear server and returns the note, or an empty string when there
 * is no note (no network, the server's limit, a bad answer). Never throws. Logs nothing about the content.
 */
export function fetchMonthNote(body: string): Promise<string> {
  const request: http.HttpRequest = http.createHttp();
  const headers: Record<string, string> = {};
  headers['Content-Type'] = 'application/json';
  const options: http.HttpRequestOptions = {
    method: http.RequestMethod.POST,
    header: headers,
    extraData: body,
    expectDataType: http.HttpDataType.STRING,
    connectTimeout: 10000,
    readTimeout: 25000
  };
  return request.request(MONTH_NOTE_URL, options)
    .then((response: http.HttpResponse): string => {
      if (response.responseCode !== 200 || typeof response.result !== 'string') {
        return '';
      }
      return monthNoteText(response.result as string);
    })
    .catch((e: BusinessError): string => {
      return '';
    })
    .finally((): void => {
      request.destroy();
    });
}
