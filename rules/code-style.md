# Code Writing Principles

## Boy Scout Principle

Leave the code cleaner than you found it. When modifying a file, fix minor issues in the affected code: poorly named variables, unnecessary nesting, duplication. Don't touch code unrelated to the current task.

## SOLID

- **Single Responsibility** — a class/module has one reason to change.
- **Open/Closed** — open for extension, closed for modification.
- **Liskov Substitution** — subtypes should be interchangeable with base types.
- **Interface Segregation** — many specialized interfaces are better than one universal interface.
- **Dependency Inversion** — dependencies point to abstractions, not concrete implementations.

## Self-Documenting Code

Comments are unnecessary. Code should be readable without them. Use clear names for functions, variables, and types that explain intent. Comments are acceptable only to explain *why*, not *what* the code does (for example, workarounds for known bugs).

## YAGNI (You Aren't Gonna Need It)

Don't add functionality "for the future." Implement only what is required right now. Three similar lines are better than premature abstraction.

## Don't Over-Engineer

- Don't create abstractions for a single use case.
- Don't add error handling for impossible scenarios.
- Don't design for hypothetical future requirements.
- Minimum complexity for the current task is the right complexity.

## DRY (Don't Repeat Yourself)

Avoid duplicating logic. If the same code appears in three or more places — extract it into a shared function. But don't confuse this with YAGNI: duplication of two similar fragments is better than an incorrect abstraction.

## Testable Code

Write code that is easy to cover with tests. Pass dependencies through arguments/constructors, don't create them inside. Avoid global state and hidden side effects.