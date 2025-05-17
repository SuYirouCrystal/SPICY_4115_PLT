#!/usr/bin/env bash
set -euo pipefail

FAILED=0
SPICYC=./spicyc.exe
TESTDIR=tests

echo "Running SPICY compiler tests..."

# Positive tests: A, B, C
for src in "$TESTDIR"/*.spicy; do
  base=$(basename "$src" .spicy)

  # Skip the negative test file
  if [ "$base" = "D" ]; then
    continue
  fi

  echo "=== Testing $base ==="
  # 1) Compile to IR
  if ! "$SPICYC" "$src" > out.ll 2> out.err; then
    echo "❌ $base: compiler error"
    cat out.err
    FAILED=1
    continue
  fi

  # 2) Normalize and diff against golden IR
  diff -u \
    <(grep -v '^;' "$TESTDIR/$base.ll" | sed '/^[[:space:]]*$/d') \
    <(grep -v '^;' out.ll           | sed '/^[[:space:]]*$/d') \
    || {
      echo "❌ $base: output mismatch"
      FAILED=1
    }
done

# Negative test: D.spicy should fail to compile
echo "=== Testing D (should fail) ==="
if "$SPICYC" "$TESTDIR/D.spicy" > out.ll 2> out.err; then
  echo "❌ D: expected failure, but compiler succeeded"
  FAILED=1
else
  echo "✅ D: compiler correctly rejected invalid code"
fi

# Cleanup
rm -f out.ll out.err

if [ $FAILED -ne 0 ]; then
  echo "Some tests failed" >&2
  exit 1
else
  echo "All tests passed 🎉"
  exit 0
fi
