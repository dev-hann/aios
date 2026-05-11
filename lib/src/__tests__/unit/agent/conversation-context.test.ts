import { describe, it, expect } from 'vitest';
import { ConversationContext } from '../../../agent/conversation-context';

describe('ConversationContext', () => {
  it('starts empty', () => {
    const ctx = new ConversationContext();
    expect(ctx.length).toBe(0);
    expect(ctx.isEmpty).toBe(true);
    expect(ctx.toPromptContext()).toBe('');
  });

  it('adds a turn and increases length', () => {
    const ctx = new ConversationContext();
    ctx.addTurn('hello', 'hi there');
    expect(ctx.length).toBe(1);
    expect(ctx.isEmpty).toBe(false);
  });

  it('formats single turn in toPromptContext', () => {
    const ctx = new ConversationContext();
    ctx.addTurn('hello', 'hi there');
    const prompt = ctx.toPromptContext();
    expect(prompt).toContain('CONVERSATION HISTORY:');
    expect(prompt).toContain('User: hello');
    expect(prompt).toContain('Assistant: hi there');
  });

  it('formats multiple turns', () => {
    const ctx = new ConversationContext();
    ctx.addTurn('q1', 'a1');
    ctx.addTurn('q2', 'a2');
    const prompt = ctx.toPromptContext();
    expect(prompt).toContain('User: q1');
    expect(prompt).toContain('Assistant: a1');
    expect(prompt).toContain('User: q2');
    expect(prompt).toContain('Assistant: a2');
  });

  it('evicts oldest turn when exceeding maxTurns', () => {
    const ctx = new ConversationContext(3);
    ctx.addTurn('q1', 'a1');
    ctx.addTurn('q2', 'a2');
    ctx.addTurn('q3', 'a3');
    ctx.addTurn('q4', 'a4');
    expect(ctx.length).toBe(3);
    const prompt = ctx.toPromptContext();
    expect(prompt).not.toContain('User: q1');
    expect(prompt).toContain('User: q2');
    expect(prompt).toContain('User: q4');
  });

  it('truncates long responses', () => {
    const ctx = new ConversationContext(5, 10);
    const longResponse = 'a'.repeat(50);
    ctx.addTurn('q', longResponse);
    const prompt = ctx.toPromptContext();
    expect(prompt).toContain('aaaaaaaaaa...');
    expect(prompt).not.toContain('a'.repeat(50));
  });

  it('does not truncate short responses', () => {
    const ctx = new ConversationContext(5, 200);
    ctx.addTurn('q', 'short');
    const prompt = ctx.toPromptContext();
    expect(prompt).toContain('Assistant: short');
    expect(prompt).not.toContain('...');
  });

  it('truncates response at exact boundary', () => {
    const ctx = new ConversationContext(5, 5);
    ctx.addTurn('q', '12345');
    const prompt = ctx.toPromptContext();
    expect(prompt).toContain('Assistant: 12345');
    expect(prompt).not.toContain('...');
  });

  it('truncates response one over boundary', () => {
    const ctx = new ConversationContext(5, 5);
    ctx.addTurn('q', '123456');
    const prompt = ctx.toPromptContext();
    expect(prompt).toContain('12345...');
  });

  it('clears all turns', () => {
    const ctx = new ConversationContext();
    ctx.addTurn('q1', 'a1');
    ctx.addTurn('q2', 'a2');
    ctx.clear();
    expect(ctx.length).toBe(0);
    expect(ctx.isEmpty).toBe(true);
    expect(ctx.toPromptContext()).toBe('');
  });

  it('tracks toolUsed but does not include in prompt', () => {
    const ctx = new ConversationContext();
    ctx.addTurn('calc 2+3', '5', 'calculator');
    const prompt = ctx.toPromptContext();
    expect(prompt).not.toContain('calculator');
    expect(prompt).toContain('User: calc 2+3');
  });

  it('handles empty strings', () => {
    const ctx = new ConversationContext();
    ctx.addTurn('', '');
    expect(ctx.length).toBe(1);
    const prompt = ctx.toPromptContext();
    expect(prompt).toContain('User: ');
    expect(prompt).toContain('Assistant: ');
  });

  it('handles maxTurns = 1', () => {
    const ctx = new ConversationContext(1);
    ctx.addTurn('q1', 'a1');
    ctx.addTurn('q2', 'a2');
    expect(ctx.length).toBe(1);
    expect(ctx.toPromptContext()).toContain('User: q2');
    expect(ctx.toPromptContext()).not.toContain('User: q1');
  });

  it('handles undefined toolUsed', () => {
    const ctx = new ConversationContext();
    ctx.addTurn('q', 'a', undefined);
    expect(ctx.length).toBe(1);
  });
});
