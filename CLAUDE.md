# TomApp - Claude Code Instructions

## Language Preference

**Please respond in Chinese for all interactions.**

所有对话、解释、文档和代码注释都应使用中文。

## Project Overview

TomApp is a Flutter cryptocurrency trading application focused on pump detection and real-time market data analysis.

## Key Technologies

- Flutter 3.24 with Dart 3.6
- `provider` 6.1.0 (ChangeNotifier) for state management
- Binance API integration
- Real-time WebSocket data streaming

## Development Guidelines

### Code Structure
- Follow the 4-layer architecture: UI → Provider → Service → Data
- Respect the existing directory structure in `lib/`
- Use Provider pattern for state management
- Implement proper error handling and loading states

### Code Quality
- Write clean, readable Dart code following Flutter conventions
- Add comprehensive tests for new features
- Document complex logic with inline comments
- Follow existing naming conventions (camelCase for variables, PascalCase for types)

### Testing
- Aim for high test coverage on business logic
- Test pump detection strategies thoroughly
- Mock external API calls in tests
- Include integration tests for critical user flows

## Related Documentation

See `.planning/codebase/` for detailed codebase analysis:
- `ARCHITECTURE.md` - System architecture and component design
- `STACK.md` - Technology stack and dependencies
- `CONVENTIONS.md` - Coding conventions and patterns
- `CONCERNS.md` - Technical debt and improvement areas
