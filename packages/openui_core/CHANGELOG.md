# Changelog

## 0.1.0 (unreleased)

- **chore**: package scaffold (Phase 0 of the OpenUI Flutter port).
- **feat**: walking-skeleton lexer covering the OpenUI Lang token set
  (identifier, type, statevar, builtin sigil, string, number, operator, punct,
  newline, EOF). This is the Spike S0.2 deliverable; the streaming-aware parser
  built on top lands in a follow-up PR.

### Phase 1 follow-ups recorded during review

- Add a recoverable-mode continuation test: feed a mostly-valid prefix with a
  broken tail (e.g. `'foo = "ok"\n$'`) and assert the prefix tokenizes cleanly
  while the tail produces the documented stub tokens. This is the exact
  scenario recoverable mode exists to support; it is best landed alongside the
  streaming parser, not in isolation.
