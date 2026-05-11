# AIOS

On-device AI Agent for Android. Built with **Gyo Framework** (React + TypeScript + WebView).

## Quick Start

```bash
# Install dependencies
cd lib && npm install

# Development (browser)
npm run dev

# Development (device)
bash /tmp/gyo run

# Build for production
bash /tmp/gyo build android
```

## Tech Stack

- **Framework**: Gyo (React + Vite + TypeScript) in WebView
- **Agent**: ReAct strategy with OpenAI-compatible tool-calling API
- **State**: Zustand
- **Storage**: IndexedDB (via idb)
- **LLM**: Remote API (glm-4-flash via z.ai)

## Project Structure

```
lib/src/
├── agent/         # ReAct strategy, error recovery, loop detection
├── components/    # React UI components
├── llm/           # OpenAI-compatible API client (SSE streaming)
├── services/      # IndexedDB, conversation storage
├── stores/        # Zustand state management
├── styles/        # CSS theme (dark mode)
├── tools/         # Agent tools (calculator, notepad, timer)
└── types/         # TypeScript type definitions

android/           # Gyo WebView shell (Kotlin)
gyo.config.json    # Gyo project configuration
```

## Documentation

- [Architecture](docs/architecture.md)
- [Contributing](CONTRIBUTING.md)
- [Testing](TESTING.md)
- [Roadmap](ROADMAP.md)
