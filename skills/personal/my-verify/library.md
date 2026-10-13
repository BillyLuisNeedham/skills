# Library strategy

Call the public interface from outside, as a consumer would. Write outputs under `{run}/library/`.

Write a scratch consumer script per claim in `{run}/library/` that imports the package through its public entry point (not deep paths into its internals) and prints inputs, outputs and thrown errors. Run it against `HEAD`, and against the base worktree for a before and after claim. Save each run's output as `{run}/library/{claim}-{nn}-{slug}.txt` with a caption stating what it proves.

Cover boundaries the diff shows: empty and maximal inputs, wrong types where the language allows them, concurrency or ordering when the code is async, and every error path the changed code adds.

Run the project's tests for the touched modules, and its type check and build. When the diff changes an exported signature or type, list the change and search the repo for callers; a caller that breaks is a finding.
