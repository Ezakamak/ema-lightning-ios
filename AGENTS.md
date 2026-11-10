# Maintainer workflow preferences

- Use GitHub Actions for tests, iOS compilation and IPA/download packaging;
  do not execute these in the cloud workspace.
- The maintainer requested code-only follow-up fixes and cancelled broad
  simulator testing. Do not start another test/build/packaging run as part of
  those fixes. Commit code-only updates with `[skip ci]` until a new run is
  requested. Report unexecuted checks honestly.
- The `run_tests` workflow-dispatch checkbox is opt-in. Normal build/package
  runs do not need full ONNX/UI tests repeated for a cosmetic change. Re-run
  only failed jobs when source is unchanged and a retry is justified.
- Keep the real offline EMA engine, original notices and the user's original
  display/history/caption text. Pronunciation hints affect synthesis only.
- Keep an attached, visible WebKit viewport; it currently occupies the Create
  tab icon. Do not remove the host or hide it in a 1×1 background when editing UI.
