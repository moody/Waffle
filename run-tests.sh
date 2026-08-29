#!/bin/bash

PASSED_COUNT=0
FAILED_COUNT=0

for TEST_FILE in $(find test -name '*-tests.lua'); do
  LUA_OUTPUT=$(lua "$TEST_FILE" 2>&1)

  if [ $? -eq 0 ]; then
    ((PASSED_COUNT+=1))
    printf "[PASS]: %s\n" "$TEST_FILE"
  else
    ((FAILED_COUNT+=1))
    printf "\n[FAIL]: %s\n" "$TEST_FILE"
    printf "$LUA_OUTPUT\n\n"
  fi
done

printf "\n------------------------------------------------------------\n"
printf "[Test Results]: %s passed, %s failed, %s total\n\n" "$PASSED_COUNT" "$FAILED_COUNT" "$((PASSED_COUNT + FAILED_COUNT))"

if [ $FAILED_COUNT -ne 0 ]; then
  exit 1
fi
