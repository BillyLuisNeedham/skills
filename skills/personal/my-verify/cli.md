# CLI strategy

Run the command as a user would and keep the transcript. Write outputs under `{run}/cli/`.

Build or install the CLI the way the project documents. For each invocation, save `{run}/cli/{claim}-{nn}-{slug}.txt` holding the exact command, the working directory, relevant environment, stdout, stderr (kept separate), the exit code, and the wall time. The caption states what the run proves.

Assert on output text, exit code, and any files the command creates or changes (list and diff them). Cover: `--help` for any new or changed flag, missing and invalid arguments, a non-interactive run (stdin closed, `CI=1`), and a rerun to check idempotency when the command writes state.

When the output is visual (colours, progress, TUI), also record it: `script -q {run}/cli/{claim}.typescript <command>` keeps the raw stream, and a screenshot of the terminal shows how it renders.
