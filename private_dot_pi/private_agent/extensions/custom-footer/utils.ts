export function formatDecimal(n: number, digits: number): string {
  return n.toFixed(digits).replace(/\.?0+$/, "");
}

/**
 * Format token counts (similar to web-ui)
 */
export function formatTokens(count: number): string {
  if (count < 1000) return count.toString();
  if (count < 10000) return `${formatDecimal(count / 1000, 1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  if (count < 10000000) return `${formatDecimal(count / 1000000, 1)}M`;
  return `${Math.round(count / 1000000)}M`;
}
