---
name: expo-dev-loop
description: Verify Expo and React Native changes in a running app with agent-device. Use after editing screens, navigation, interactions, app configuration, config plugins, native dependencies, permissions, startup behavior, or performance, or whenever the user asks to confirm an Expo change on an iOS or Android simulator, emulator, or physical device. Classify whether the change can use the Metro fast path or requires a native rebuild, then finish only with observable runtime evidence.
---

# Expo Dev Loop

Prove the changed behavior in the running app. Static inspection, type checks,
unit tests, and a successful bundle support the result but do not replace device
verification.

## Establish the target

Inspect the request, current diff, Expo config, and package manifest. Identify
the intended flow, platform, device, and observable result. When the request
does not require both platforms, use one available representative local target
and state that coverage; never infer iOS and Android parity from one run.

Use the installed CLI's version-matched guidance instead of remembered command
shapes:

```bash
agent-device help workflow
agent-device help react-native
```

If `agent-device` is unavailable, report that runtime verification is blocked
and give `npm install -g agent-device@latest` as the setup command.

## Choose the runtime path

Classify the whole change before launching the app:

- **Metro path:** JavaScript or TypeScript behavior, React components, styles,
  navigation code, and bundle-loaded assets that do not alter the native app.
  Reuse the running Expo Go or development build and Metro server. Let Fast
  Refresh apply the change or use `agent-device metro reload` when a full JS
  reload is needed.
- **Native path:** Expo app config that affects the binary, config plugins,
  native modules or dependencies, permissions, entitlements, icons or splash
  configuration, native project files, SDK or React Native upgrades, and
  startup behavior. Use the repository-supported build command, normally
  `npx expo run:ios` or `npx expo run:android`, install the resulting
  development build, and relaunch it.

Use the native path for a mixed change or when native impact remains uncertain.
Expo Go cannot prove a native change; use a development build. Preserve the
project's managed or checked-in native workflow rather than regenerating native
directories as an incidental verification step.

## Prepare the observation loop

Keep state-changing device commands serial within one session. Open the actual
installed app identifier, development-client URL, or Expo Go project URL
reported by the running tools; do not invent one. Use `open --relaunch` when
startup or clean process state matters, then capture the initial interactive
snapshot.

When Expo MCP local capabilities are already available, use its Router sitemap,
current Expo documentation, or short app-log collection as framework-side
context. Treat them as optional discovery and diagnostics; `agent-device`
remains the device-side proof.

## Verify after each edit

Exercise the smallest complete user flow affected by the edit and check four
layers:

1. **Loaded:** the intended Metro update or native build is running on the
   selected target, with no bundle, build, or incompatible-client error.
2. **Healthy:** reproduce inside a focused log window and check for relevant
   JavaScript errors, native crashes, RedBox or LogBox failures, and rejected
   network requests.
3. **Correct:** drive the flow with `press`, `fill`, `scroll`, `back`, and other
   appropriate commands using `--settle`; verify the named outcome with an
   exact `wait`, `is`, `get`, or `find` assertion. A screenshot alone does not
   prove a behavioral expectation.
4. **Sound at the claimed layer:** inspect the React tree, props, hooks,
   re-renders, native performance, network data, or traces only when the change
   makes a claim about that layer.

Use refs from the latest snapshot or settled diff. A state-changing command
invalidates earlier refs; refresh the snapshot or use a stable id, label, role,
or testID before the next action. Prefer semantic selectors and use coordinates
only when the accessibility surface cannot expose the target, recording that
limitation with visual evidence.

Collect evidence proportional to the claim: a screenshot for visual output,
focused logs for runtime behavior, network output for request behavior,
performance artifacts for performance claims, and a recorded `.ad` replay for
a flow worth keeping as a regression check.

## Finish the loop

Finish only when the selected runtime contains the current change, the exact
user-visible expectation passes, relevant runtime errors are absent during the
reproduction, and every platform claim has device evidence. Report the target,
flow, assertions, and artifact paths, separating observed results from
remaining inference or unverified coverage.

If verification is blocked, name the app, platform, session, failed gate, and
the exact next command or user action needed. Close the `agent-device` session
when finished. Leave a healthy Metro server running for the next edit loop
unless the user requested cleanup; in CI, release the device with
`agent-device close --shutdown`.
