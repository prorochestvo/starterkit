# Verification

### Sweep the whole bug class named by a change (R30)

If a change identifies a general hazard/class, inspect every site of
that class in the same change. Do not fix one occurrence while
documenting a repository-wide problem.

### Proof transforms must not erase the property being proved (R32)

A verification/diff may normalize irrelevant differences, but never
normalize the exact axis the change is supposed to prove. If proving a
pure move, the comparison must still detect content loss/change.

### Verification must prove it actually ran (R36)

A mutation/gate is evidence only if: - the mutation target was found and
changed; - the command producing the verdict is the command whose status
was read; - build/setup failure is not mistaken for a passing test; -
the files checked were not concurrently rewritten.

Tests that loop over globs/directories/file lists must assert the
collection is non-empty. After moving packages, re-check relative paths
used by tests.

### Lowering a guard floor requires the reason (R37)

When a minimum-count guard legitimately decreases, change both the
number and its invariant comment. State what subject disappeared and
why. Never lower a floor merely to make the test green.
