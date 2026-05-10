export function inferToolArgs(toolName: string, userMessage: string): Record<string, unknown> | null {
  const msg = userMessage.toLowerCase();

  switch (toolName) {
    case 'calculator': {
      const mathMatch = msg.match(/([\d.]+)\s*([+\-×÷*/xX]\s*[\d.]+)+/);
      if (mathMatch) {
        return { expression: mathMatch[0].replace(/[xX]/g, '*').replace(/[÷]/g, '/') };
      }
      const numMatch = msg.match(/([\d.]+)\s*(더하기|빼기|곱하기|나누기|plus|minus|times|divided)\s*([\d.]+)/i);
      if (numMatch) {
        const op = numMatch[2]
          .replace('더하기', '+').replace('plus', '+')
          .replace('빼기', '-').replace('minus', '-')
          .replace('곱하기', '*').replace('times', '*')
          .replace('나누기', '/').replace('divided', '/');
        return { expression: `${numMatch[1]}${op}${numMatch[3]}` };
      }
      return null;
    }

    case 'notepad': {
      const memoMatch = userMessage.match(/(?:메모|기록|저장|memo|note|save)[:\s]*(.+)/i);
      if (memoMatch) return { action: 'save', key: 'memo', value: memoMatch[1].trim() };
      return null;
    }

    case 'timer': {
      const minMatch = msg.match(/(\d+)\s*분/);
      if (minMatch) return { action: 'set', seconds: parseInt(minMatch[1]) * 60 };
      const secMatch = msg.match(/(\d+)\s*초/);
      if (secMatch) return { action: 'set', seconds: parseInt(secMatch[1]) };
      return null;
    }

    default:
      return null;
  }
}
