# Rule: ad-hoc / scratch work hygiene

This fires for loose work outside any project. Keep it tidy:

- Don't litter `$HOME` or the desktop with throwaway files. Put scratch work in a temp dir
  (`mktemp -d`) or a clearly-named `~/scratch/` folder, and clean up when done.
- For anything beyond a quick one-liner, `git init` a throwaway repo so changes are recoverable —
  and still work on a branch, not straight on the default branch.
- Before running a destructive command (`rm -rf`, overwriting a file, force operations), show me
  what it will affect and confirm — there's no project gate or review here to catch mistakes.
- Don't claim a script works until I've actually run it and seen the expected output.
