export type Money = Readonly<{ amountMinor: bigint; currency: string }>;

export function money(amountMinor: bigint, currency: string): Money {
  if (!/^[A-Z]{3}$/.test(currency)) throw new Error("INVALID_CURRENCY");
  return Object.freeze({ amountMinor, currency });
}

export function addMoney(left: Money, right: Money): Money {
  if (left.currency !== right.currency) throw new Error("CURRENCY_MISMATCH");
  return money(left.amountMinor + right.amountMinor, left.currency);
}

export function applyBasisPoints(value: Money, rateBps: number): Money {
  if (!Number.isInteger(rateBps)) throw new Error("INVALID_BASIS_POINTS");
  const numerator = value.amountMinor * BigInt(rateBps);
  const sign = numerator < 0n ? -1n : 1n;
  const absolute = numerator * sign;
  const rounded = (absolute + 5_000n) / 10_000n;
  return money(rounded * sign, value.currency);
}
