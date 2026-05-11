export interface ConversationTurn {
  userMessage: string;
  assistantResponse: string;
  toolUsed?: string;
}

export class ConversationContext {
  private turns: ConversationTurn[] = [];

  constructor(
    private maxTurns = 5,
    private maxResponseLength = 200,
  ) {}

  get length(): number {
    return this.turns.length;
  }

  get isEmpty(): boolean {
    return this.turns.length === 0;
  }

  addTurn(userMessage: string, assistantResponse: string, toolUsed?: string): void {
    this.turns.push({ userMessage, assistantResponse, toolUsed });
    while (this.turns.length > this.maxTurns) {
      this.turns.shift();
    }
  }

  toPromptContext(): string {
    if (this.turns.length === 0) return '';
    const lines: string[] = ['CONVERSATION HISTORY:'];
    for (const turn of this.turns) {
      const response =
        turn.assistantResponse.length > this.maxResponseLength
          ? turn.assistantResponse.substring(0, this.maxResponseLength) + '...'
          : turn.assistantResponse;
      lines.push(`User: ${turn.userMessage}`);
      lines.push(`Assistant: ${response}`);
    }
    return lines.join('\n');
  }

  clear(): void {
    this.turns = [];
  }
}
