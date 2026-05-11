import type { ToolResult } from '../types/agent';
import { toolResultOk, toolResultErr } from '../types/agent';
import { tryParseToolJson } from '../agent/tool-json-parser';
import type { AgentTool } from './types';

export class CalculatorTool implements AgentTool {
  readonly name = 'calculator';
  readonly description = 'Evaluate math expression. Args: {expression}';
  readonly parameters = '{"expression": "string (e.g. \\"2+3\\", \\"10*5\\", \\"(4+1)/2\\")"}';
  readonly toolPrompt =
    'Evaluate a mathematical expression.\n\n' +
    'Parameters: ' + this.parameters + '\n\n' +
    'Rules:\n' +
    '- "expression" is required\n' +
    '- Supports +, -, *, /, parentheses\n' +
    '- Korean: "더하기" → +, "빼기" → -, "곱하기" → *, "나누기" → /';

  async validate(args: string): Promise<string | null> {
    const json = tryParseToolJson(args);
    const expr = (json['expression'] as string) ?? '';
    if (!expr) return "'expression' required";
    const sanitized = expr.replace(/[^0-9+\-*/.()% ]/g, '');
    if (!sanitized) return "'expression' must contain valid math operators";
    return null;
  }

  async execute(args: string): Promise<ToolResult> {
    try {
      const json = tryParseToolJson(args);
      const expr = (json['expression'] as string) ?? '';
      const sanitized = expr.replace(/[^0-9+\-*/.()% ]/g, '');
      if (!sanitized) return toolResultErr("'expression' required");
      const result = this.evalExpr(sanitized);
      return toolResultOk(result.toFixed(4));
    } catch (e) {
      return toolResultErr(`${e}`);
    }
  }

  private evalExpr(expr: string): number {
    const tokens = expr.replace(/ /g, '').split('');
    const values: number[] = [];
    const ops: string[] = [];
    const precedence: Record<string, number> = { '+': 1, '-': 1, '*': 2, '/': 2 };
    let i = 0;

    const applyOp = (): void => {
      const b = values.pop()!;
      const a = values.pop()!;
      const op = ops.pop()!;
      switch (op) {
        case '+': values.push(a + b); break;
        case '-': values.push(a - b); break;
        case '*': values.push(a * b); break;
        case '/': values.push(a / b); break;
      }
    };

    while (i < tokens.length) {
      const c = tokens[i];
      if (c === '(') {
        ops.push(c);
      } else if (c === ')') {
        while (ops.length > 0 && ops[ops.length - 1] !== '(') applyOp();
        ops.pop();
      } else if (/[0-9.]/.test(c)) {
        let num = '';
        while (i < tokens.length && /[0-9.]/.test(tokens[i])) {
          num += tokens[i];
          i++;
        }
        values.push(parseFloat(num));
        continue;
      } else if (precedence[c] != null) {
        while (ops.length > 0 && precedence[ops[ops.length - 1]] != null && precedence[ops[ops.length - 1]] >= precedence[c]) {
          applyOp();
        }
        ops.push(c);
      }
      i++;
    }
    while (ops.length > 0) applyOp();
    return values[values.length - 1];
  }
}
