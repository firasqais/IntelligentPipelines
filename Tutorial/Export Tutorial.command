#!/bin/zsh
# Double-click to build "IntelligencePipeline Tutorial.doccarchive" next to this file.
# Participants double-click that archive to open the tutorial in Xcode.
cd "$(dirname "$0")"
OUT="IntelligencePipeline Tutorial.doccarchive"
rm -rf "$OUT"
xcrun docc convert IntelligencePipeline.docc \
  --fallback-display-name "IntelligencePipeline" \
  --fallback-bundle-identifier au.edu.uts.IntelligencePipeline.tutorial \
  --output-dir "$OUT" && echo "\nDone: $OUT" && open -R "$OUT"
