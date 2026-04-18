export function formatDecimal(n: number, digits: number): string {
  return n.toFixed(digits).replace(/\.?0+$/, "");
}
