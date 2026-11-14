#!/bin/sh
set -eu

if grep -R -n -E 'document\.|window\.|localStorage|navigator\.|</?(div|span|button|input|p|a|ul|ol|li|section|article|form|svg|img|table|tr|td|th|canvas|iframe)([[:space:]>])|className=|onClick=' client/ index.client.tsx; then
  echo "audit-client: forbidden browser-only client construct" >&2
  exit 1
fi

if grep -R -n -E 'from "(react-native-svg|lucide-react-native)"|from '\''(react-native-svg|lucide-react-native)'\''' client/ index.client.tsx; then
  echo "audit-client: forbidden client dependency" >&2
  exit 1
fi

echo "audit-client: PASS"
