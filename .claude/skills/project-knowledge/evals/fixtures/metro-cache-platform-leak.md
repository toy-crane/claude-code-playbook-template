# Metro transform cache is not keyed by platform

**Symptom**: The Android bundle contained `127.0.0.1` as the dev server host, so
the app could not reach Metro. Android requires `10.0.2.2` from the emulator.

**Observed evidence**: Bundling for Android right after an iOS session produced
the iOS host constant. Clearing the Metro cache and re-bundling produced
`10.0.2.2` on the same checkout and the Android session then verified normally.

**Suspected cause**: The Metro transform cache lives in a machine-global
temporary directory and is shared by every checkout on the machine. The cache
key appears to omit the target platform, so a transform result produced for iOS
is reused for an Android bundle.

**What was tried**: Cleared the cache and reopened the Android session. This
unblocked verification but leaves the sharing behavior unchanged, so the next
iOS-then-Android sequence can reproduce it. No product code was changed.

**Proposed next step**: Inspect the project's Metro config and Expo version, and
confirm whether the platform belongs in the cache key or whether the shared
cache directory should be scoped per platform.
