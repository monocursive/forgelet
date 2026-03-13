#!/bin/sh
if [ "$MOCK_CLAUDE_SCENARIO" = "timeout" ]; then
  sleep 30
  exit 0
fi

echo "mock claude session"
exit 0
