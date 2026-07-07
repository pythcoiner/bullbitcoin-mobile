#!/usr/bin/env bash
# audit-sp-invariant.sh: Static analysis enforcing SP no-autoscan invariants.
set -euo pipefail

fail=0

echo '=== scanOnce call sites (must be only the port, adapter + ScanSpWalletUsecase) ==='
rg -nF 'scanOnce(' lib/ || true
bad=$(rg -lF 'scanOnce(' lib/ \
  | rg -v 'lib/features/sp/application/ports/sp_account_repository\.dart$' \
  | rg -v 'lib/features/sp/adapters/bwk_sp_account_repository\.dart$' \
  | rg -v 'lib/features/sp/application/usecases/scan_sp_wallet_usecase\.dart$' \
  || true)
if [ -n "$bad" ]; then
  echo "FAIL: scanOnce called from forbidden file(s):"
  echo "$bad"
  fail=1
fi

echo ''
echo '=== ScanSpWalletUsecase users (must be only definition, locator, router, cubit, and comments) ==='
rg -nF 'ScanSpWalletUsecase' lib/ || true
# Match real code references only — exclude comment lines (// , /// , *) so
# doc comments that merely name the use case (incl. FRB-generated docs) don't
# trip the check.
bad=$(rg -nF 'ScanSpWalletUsecase' lib/ \
  | rg -v '^[^:]+:[0-9]+:[[:space:]]*(///|//|\*)' \
  | cut -d: -f1 | sort -u \
  | rg -v 'lib/features/sp/application/usecases/scan_sp_wallet_usecase\.dart$' \
  | rg -v 'lib/features/sp/sp_locator\.dart$' \
  | rg -v 'lib/features/sp/presentation/cubit\.dart$' \
  || true)
if [ -n "$bad" ]; then
  echo "FAIL: ScanSpWalletUsecase referenced from forbidden file(s):"
  echo "$bad"
  fail=1
fi

echo ''
echo '=== Lifecycle / background hooks in SP code (must be empty) ==='
if rg -n 'WidgetsBindingObserver|onResume|onForeground|Workmanager' \
     lib/features/sp 2>/dev/null; then
  echo "FAIL: lifecycle hook present in SP code"
  fail=1
else
  echo "PASS: no lifecycle hooks in SP code"
fi

echo ''
if [ $fail -ne 0 ]; then
  echo "RESULT: SP invariant audit FAILED ($fail violation(s) found)."
  exit 1
fi
echo 'OK: SP invariant audit passed.'
