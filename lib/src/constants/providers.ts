export const PROVIDER_TYPES = [
  { value: 'zai', label: 'Z.AI' },
  { value: 'zaiCoding', label: 'Z.AI (Coding)' },
  { value: 'openai', label: 'OpenAI' },
  { value: 'anthropic', label: 'Anthropic' },
  { value: 'custom', label: 'Custom' },
] as const;

export function getProviderLabel(value: string): string {
  return PROVIDER_TYPES.find((p) => p.value === value)?.label ?? value;
}
