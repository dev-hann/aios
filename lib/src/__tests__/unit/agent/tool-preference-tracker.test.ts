import { describe, it, expect } from 'vitest';
import { ToolPreferenceTracker } from '../../../agent/tool-preference-tracker';

describe('ToolPreferenceTracker', () => {
  it('returns empty string when no tools recorded', () => {
    const tracker = new ToolPreferenceTracker();
    expect(tracker.toPromptContext()).toBe('');
  });

  it('records single tool and shows in prompt', () => {
    const tracker = new ToolPreferenceTracker();
    tracker.recordToolUse('calculator');
    const prompt = tracker.toPromptContext();
    expect(prompt).toContain('FREQUENTLY USED TOOLS:');
    expect(prompt).toContain('- calculator (1 uses)');
  });

  it('tracks multiple uses of same tool', () => {
    const tracker = new ToolPreferenceTracker();
    tracker.recordToolUse('calculator');
    tracker.recordToolUse('calculator');
    tracker.recordToolUse('calculator');
    const prompt = tracker.toPromptContext();
    expect(prompt).toContain('- calculator (3 uses)');
  });

  it('sorts by frequency descending', () => {
    const tracker = new ToolPreferenceTracker();
    tracker.recordToolUse('calculator');
    tracker.recordToolUse('notepad');
    tracker.recordToolUse('notepad');
    tracker.recordToolUse('notepad');
    tracker.recordToolUse('calculator');
    const prompt = tracker.toPromptContext();
    const notepadIdx = prompt.indexOf('notepad');
    const calcIdx = prompt.indexOf('calculator');
    expect(notepadIdx).toBeLessThan(calcIdx);
  });

  it('limits to topN tools', () => {
    const tracker = new ToolPreferenceTracker(2);
    tracker.recordToolUse('calculator');
    tracker.recordToolUse('notepad');
    tracker.recordToolUse('notepad');
    tracker.recordToolUse('timer');
    tracker.recordToolUse('timer');
    tracker.recordToolUse('timer');
    const prompt = tracker.toPromptContext();
    expect(prompt).toContain('timer');
    expect(prompt).toContain('notepad');
    expect(prompt).not.toContain('calculator');
  });

  it('clears all tracking data', () => {
    const tracker = new ToolPreferenceTracker();
    tracker.recordToolUse('calculator');
    tracker.recordToolUse('notepad');
    tracker.clear();
    expect(tracker.toPromptContext()).toBe('');
  });

  it('handles default topN of 3', () => {
    const tracker = new ToolPreferenceTracker();
    tracker.recordToolUse('a');
    tracker.recordToolUse('b');
    tracker.recordToolUse('c');
    tracker.recordToolUse('d');
    tracker.recordToolUse('d');
    const prompt = tracker.toPromptContext();
    expect(prompt).toContain('d');
    const lines = prompt.split('\n').filter((l) => l.startsWith('-'));
    expect(lines.length).toBe(3);
  });

  it('records empty string tool name without error', () => {
    const tracker = new ToolPreferenceTracker();
    tracker.recordToolUse('');
    const prompt = tracker.toPromptContext();
    expect(prompt).toContain('-  (1 uses)');
  });
});
