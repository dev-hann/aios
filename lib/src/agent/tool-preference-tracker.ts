export class ToolPreferenceTracker {
  private usage = new Map<string, number>();

  constructor(private topN = 3) {}

  recordToolUse(toolName: string): void {
    this.usage.set(toolName, (this.usage.get(toolName) ?? 0) + 1);
  }

  toPromptContext(): string {
    const top = this.getMostUsed(this.topN);
    if (top.length === 0) return '';
    const lines: string[] = ['FREQUENTLY USED TOOLS:'];
    for (const tool of top) {
      lines.push(`- ${tool} (${this.usage.get(tool)} uses)`);
    }
    return lines.join('\n');
  }

  private getMostUsed(count?: number): string[] {
    const sorted = [...this.usage.entries()].sort((a, b) => b[1] - a[1]);
    return sorted.slice(0, count ?? sorted.length).map(([k]) => k);
  }

  clear(): void {
    this.usage.clear();
  }
}
