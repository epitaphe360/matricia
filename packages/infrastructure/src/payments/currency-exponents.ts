import { PaymentGatewayError, type PaymentGatewayCode } from "./contracts";

const supportedCurrencyExponents = new Map<string, number>([
  ["MAD", 2],
  ["AUD", 2],
  ["CAD", 2],
  ["CHF", 2],
  ["EUR", 2],
  ["GBP", 2],
  ["USD", 2],
]);

export function assertGatewayCurrency(gateway: PaymentGatewayCode, currency: string): number {
  const exponent = supportedCurrencyExponents.get(currency);
  if (exponent !== 2 || (gateway === "CMI" && currency !== "MAD")) {
    throw new PaymentGatewayError("INVALID_CURRENCY");
  }
  return exponent;
}

export function isSupportedTwoDecimalCurrency(currency: string): boolean {
  return supportedCurrencyExponents.get(currency) === 2;
}
