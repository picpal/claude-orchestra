# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-26

### Added

#### Agents (12)
- **Maestro** - User interaction and intent classification
- **Planner** - TODO orchestration, verification, and git commit
- **Interviewer** - Requirements interview and plan creation
- **Plan-Checker** - Plan analysis and missed question detection
- **Plan-Reviewer** - Plan verification and TDD compliance check
- **Architecture** - Architecture advice and debugging support
- **Searcher** - External documentation search
- **Explorer** - Internal codebase search
- **Image-Analyst** - Image analysis
- **High-Player** - Complex task execution
- **Low-Player** - Simple task execution
- **Code-Reviewer** - Code review (25+ dimensions)

#### Commands (10)
- `/start-work` - Start work session
- `/status` - Check current status
- `/tdd-cycle` - TDD cycle guide
- `/verify` - Run verification loop
- `/code-review` - Code review
- `/learn` - Continuous learning
- `/checkpoint` - State snapshot
- `/e2e` - E2E test execution
- `/refactor-clean` - Safe refactoring mode
- `/update-docs` - Documentation sync
- `/context` - Context mode switch

#### Hooks (15)
- `tdd-guard.sh` - Prevent test deletion
- `test-logger.sh` - Log test results and TDD metrics
- `verification-loop.sh` - 6-stage verification orchestrator
- `build-check.sh` - Build verification
- `type-check.sh` - Type safety check
- `lint-check.sh` - Code style check
- `test-coverage.sh` - Test execution and coverage
- `security-scan.sh` - Security vulnerability scan
- `diff-review.sh` - Change review
- `verification-report.sh` - Verification report generator
- `evaluate-session.sh` - Session pattern extraction
- `suggest-compact.sh` - Context compaction suggestion
- `auto-format.sh` - Auto formatting
- `git-push-review.sh` - Pre-push review
- `load-context.sh` - Session context loading
- `save-context.sh` - Session context saving

#### Rules (6)
- `security.md` - Security rules
- `testing.md` - Testing rules
- `git-workflow.md` - Git workflow rules
- `coding-style.md` - Coding style rules
- `performance.md` - Performance guidelines
- `agent-rules.md` - Agent usage rules

#### Contexts (3)
- `dev.md` - Development context
- `research.md` - Research context
- `review.md` - Review context

#### Features
- TDD enforcement with TEST → IMPL → REFACTOR cycle
- 6-stage verification loop (Build, Types, Lint, Tests, Security, Diff)
- Continuous learning system for pattern extraction
- Strategic compaction for context optimization
- Automatic git commit on PR Ready
- Intent classification (TRIVIAL, EXPLORATORY, AMBIGUOUS, OPEN-ENDED)
- Complexity-based executor selection (High/Low Player)
- 25+ dimension code review
- MCP integration support (Context7)

#### Installation
- `install.sh` - Installation script
- `uninstall.sh` - Uninstallation script
- Plugin marketplace support

### Technical Details
- Supports TypeScript, JavaScript, Python, Go, Rust
- Works with Jest, Vitest, Pytest, Go test
- ESLint, Biome, Ruff, golangci-lint support
- Playwright, Cypress E2E support
- Minimum 80% code coverage requirement
- 100% coverage for security/payment/auth logic
