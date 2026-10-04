/*
 * Polskie etykiety dla wartości z modelu i tokenu.
 */
export class Labels {
  static tier(tier: string): string {
    if (tier === 'ZLOTY') {
      return 'Złoty';
    }
    if (tier === 'SREBRNY') {
      return 'Srebrny';
    }
    if (tier === 'BRAK') {
      return 'Bez zniżki (składka bez zmian)';
    }
    return tier;
  }

  static tierShort(tier: string): string {
    if (tier === 'ZLOTY') {
      return 'Złoty';
    }
    if (tier === 'SREBRNY') {
      return 'Srebrny';
    }
    return 'Bez zniżki';
  }

  static status(status: string): string {
    if (status === 'OK') {
      return 'OK';
    }
    if (status === 'REVIEW') {
      return 'Do przeglądu przez człowieka';
    }
    return status;
  }

  static assurance(a: string): string {
    if (a === 'ROZSZERZONY' || a === 'EXT') {
      return 'Rozszerzony (ruch + tętno)';
    }
    if (a === 'PODSTAWOWY' || a === 'BASIC') {
      return 'Podstawowy (tylko ruch) — maks. próg Srebrny';
    }
    return a;
  }

  static consents(codes: string[]): string {
    const names: string[] = [];
    for (const c of codes) {
      if (c === 'steps') {
        names.push('ruch');
      } else if (c === 'hr') {
        names.push('tętno');
      } else if (c === 'sleep') {
        names.push('sen');
      } else {
        names.push(c);
      }
    }
    return names.join(', ');
  }

  static weekStatus(status: string): string {
    if (status === 'MET') {
      return 'Zaliczony';
    }
    if (status === 'NOT_MET') {
      return 'Niezaliczony';
    }
    if (status === 'NO_DATA') {
      return 'Za mało danych';
    }
    if (status === 'REVIEW') {
      return 'Do przeglądu';
    }
    return status;
  }

  /** Przyjmuje pełne kody z modelu i krótkie kody z tokenu. */
  static flag(code: string): string {
    if (code === 'STEPS_WITHOUT_HR' || code === 'SWHR') {
      return 'Kroki bez wzrostu tętna';
    }
    if (code === 'STEPS_WHILE_NOT_WORN' || code === 'SWNW') {
      return 'Kroki przy zdjętym zegarku';
    }
    if (code === 'IMPOSSIBLE_VALUE' || code === 'IMPV') {
      return 'Wartości niemożliwe fizjologicznie';
    }
    if (code === 'NOT_WORN' || code === 'NWRN') {
      return 'Za krótko noszony';
    }
    return code;
  }

  /** "SWHR:5,SWNW:1" -> "Kroki bez wzrostu tętna: 5 dni, Kroki przy zdjętym zegarku: 1 dzień" */
  static flagSummary(flags: string): string {
    const parts: string[] = [];
    for (const item of flags.split(',')) {
      const pair = item.split(':');
      if (pair.length === 2) {
        const n = Number(pair[1]);
        parts.push(`${Labels.flag(pair[0])}: ${n} ${n === 1 ? 'dzień' : 'dni'}`);
      } else if (item.length > 0) {
        parts.push(Labels.flag(item));
      }
    }
    return parts.join(', ');
  }

  /** Przykładowy cennik po stronie ubezpieczyciela. Aplikacja nie liczy ceny, tylko dowód. */
  static exampleDiscountPct(tier: string): number {
    if (tier === 'ZLOTY') {
      return 10;
    }
    if (tier === 'SREBRNY') {
      return 5;
    }
    return 0;
  }
}
