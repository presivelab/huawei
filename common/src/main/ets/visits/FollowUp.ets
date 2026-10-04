import { ADHERENCE_NONE, ADHERENCE_ON_TIME, Adherence, daysBetween, Visit } from './VisitTypes';

/*
 * Did the user come back when the doctor asked? One fact, from two dates: the date the follow-up was due
 * and the date of the visit that was the follow-up. The due date is kept on the visit itself, so the
 * answer does not change when the recording and its notes are deleted.
 */

/** On time when the follow-up visit took place on or before the due date. Anything unknown is NONE. */
export function adherence(dueDate: string | undefined, followUpVisitDate: string | undefined): Adherence {
  if (dueDate === undefined || followUpVisitDate === undefined) {
    return ADHERENCE_NONE;
  }
  const late = daysBetween(dueDate, followUpVisitDate);
  if (isNaN(late)) {
    return ADHERENCE_NONE;
  }
  return late <= 0 ? ADHERENCE_ON_TIME : ADHERENCE_NONE;
}

export function visitById(visits: Visit[], id: string | undefined): Visit | null {
  if (id === undefined) {
    return null;
  }
  for (let i = 0; i < visits.length; i++) {
    if (visits[i].id === id) {
      return visits[i];
    }
  }
  return null;
}

/** The date of a visit: the date its receipt was issued. Undefined without a receipt. */
export function visitDateOf(visit: Visit): string | undefined {
  const receipt = visit.receipt;
  return receipt === undefined ? undefined : receipt.issueDate;
}

/**
 * The adherence a claim of this visit states: on time when this visit is the follow-up of another one
 * and took place by that visit's due date. A visit that is not linked to an earlier one states NONE.
 */
export function visitAdherence(visit: Visit, visits: Visit[]): Adherence {
  const earlier = visitById(visits, visit.followUpOfVisitId);
  if (earlier === null) {
    return ADHERENCE_NONE;
  }
  return adherence(earlier.followUpDueDate, visitDateOf(visit));
}

/** The visit that is the follow-up of this one, or null when none has been added. */
export function followUpVisitOf(visit: Visit, visits: Visit[]): Visit | null {
  for (let i = 0; i < visits.length; i++) {
    if (visits[i].followUpOfVisitId === visit.id) {
      return visits[i];
    }
  }
  return null;
}

/** True when the follow-up this visit asked for was kept by its due date. */
export function followUpDoneOnTime(visit: Visit, visits: Visit[]): boolean {
  const later = followUpVisitOf(visit, visits);
  return later !== null && adherence(visit.followUpDueDate, visitDateOf(later)) === ADHERENCE_ON_TIME;
}
