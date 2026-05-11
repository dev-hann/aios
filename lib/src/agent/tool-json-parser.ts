export function tryParseToolJson(args: string): Record<string, unknown> {
  try {
    const decoded = JSON.parse(args);
    if (decoded && typeof decoded === 'object' && !Array.isArray(decoded)) {
      return decoded as Record<string, unknown>;
    }
    return {};
  } catch {
    return {};
  }
}

export function parseIntDynamic(value: unknown): number | null {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const parsed = parseInt(value, 10);
    return isNaN(parsed) ? null : parsed;
  }
  return null;
}
