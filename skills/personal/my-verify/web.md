# Web strategy

Drive the real app in a real browser and record it. Write outputs under `{run}/web/`.

## Start the app

Find the dev or preview command from the project (`package.json` scripts, `Makefile`, README). Run it in the background with stdout and stderr redirected to `{run}/web/server.log`, and wait until the port answers. The `run` skill knows launch patterns if the project is unusual.

## Pick the driver

- **Project Playwright**: when the project has a Playwright config, write specs into the run folder and run them with the project's runner: `npx playwright test <spec> --config <project config> --output {run}/web/pw --video=on --trace=on`.
- **Standalone Playwright** (the default otherwise): keep tooling out of the project and out of the run folder. Install once into `~/.cache/my-verify/playwright` (`npm init -y && npm i playwright && npx playwright install chromium`), write the script as `{run}/web/verify.cjs`, and run it with `NODE_PATH=~/.cache/my-verify/playwright/node_modules node {run}/web/verify.cjs`.
- **Chrome extension** (`claude-in-chrome`): only when a flow needs the user's logged-in session. Record with `gif_creator`, capturing extra frames before and after each action.

## Record one clip per flow

One browser context per flow, so each flow yields one short clip:

```js
const context = await browser.newContext({
  recordVideo: { dir: tmpDir, size: { width: 1280, height: 720 } },
  viewport: { width: 1280, height: 720 },
});
await context.tracing.start({ screenshots: true, snapshots: true });
```

Launch with `slowMo: 150` so a human can follow the clip. Before each step, stamp a caption into the page so the video explains itself:

```js
await page.evaluate((t) => {
  let el = document.getElementById('__verify_step');
  if (!el) {
    el = Object.assign(document.createElement('div'), { id: '__verify_step' });
    el.style.cssText = 'position:fixed;left:12px;bottom:12px;z-index:2147483647;padding:6px 10px;background:#111;color:#fff;font:13px system-ui;border-radius:6px;pointer-events:none';
    document.body.appendChild(el);
  }
  el.textContent = t;
}, 'C1 · Submit with empty email');
```

Re-stamp after every navigation. Take a screenshot at each meaningful state and assert on what the claim promises (text, URL, element state), so the verdict rests on an assertion, not a glance.

At the end of each flow: `context.tracing.stop({ path: '{run}/web/{claim}-trace.zip' })`, then close the context, then `page.video().saveAs(...)`. Convert each clip to mp4 so every browser plays it:

```sh
ffmpeg -y -i in.webm -c:v libx264 -pix_fmt yuv420p -movflags +faststart {claim}-{nn}-{slug}.mp4
```

## Capture logs

Attach listeners before navigating and write each flow's log to `{run}/web/{claim}-browser.log`: `console` (all levels), `pageerror`, `requestfailed`, and every `response` with status >= 400 (method, URL, status, body excerpt). Any uncaught page error during a flow is a finding even when the claim passes; put it in `risks`.

## Also check

- One narrow viewport (390x844) for any visual claim.
- Keyboard reachability of new interactive elements.
- That the reload or back-button state matches what the claim implies.

## Reproduce

Return the script path and the exact command to rerun it, plus `npx playwright show-trace <trace.zip>` for each trace.
