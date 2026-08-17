---
name: grill-me
description: Manually starts a rigorous one-question-at-a-time interview to stress-test an idea, plan, design, or decision before implementation. Use only when the user explicitly invokes grill-me or asks to be grilled; delegate the interview to the grilling skill and require an agreed plan under _local/plans/ before implementation.
---

# Grill Me

Start the `grilling` skill with the user's idea, plan, design, or decision as its subject.

If the client supports explicit skill delegation, invoke `$grilling`. Otherwise, load the installed sibling `grilling` skill and follow its workflow directly.

Do not implement the subject directly from this entry-point skill. Complete the interview, obtain the user's confirmation of shared understanding, create the required `_local/plans/YYYY-MM-DD-<slug>.md`, and wait for a separate instruction to implement.

Adapted from Matt Pocock's `grill-me` and `grilling` skills under the MIT License. See `LICENSE.txt`.
