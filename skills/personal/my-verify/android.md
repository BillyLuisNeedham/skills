# Android strategy

Install the build on an emulator, drive it, record it. Write outputs under `{run}/android/`.

## Device and build

Lease an emulator first with `agent-device lease` and use the serial it prints for every `adb -s <serial>` call. Release it with `agent-device release` during cleanup, whatever happened.

Build the debug variant (run Gradle in the background; builds queue behind a machine-wide lock) and install it with `adb -s <serial> install -r`. For a before and after run, build and install the base worktree's APK, capture its flows, then reinstall `HEAD`'s.

## Record one clip per flow

```sh
adb -s $S logcat -c
adb -s $S shell screenrecord --bit-rate 4000000 /sdcard/{claim}.mp4 &   # 3 minute hard cap per clip
# ... drive the flow ...
adb -s $S shell pkill -INT screenrecord; sleep 2
adb -s $S pull /sdcard/{claim}.mp4 {run}/android/{claim}-{nn}-{slug}.mp4
adb -s $S logcat -d --pid=$(adb -s $S shell pidof -s <package>) > {run}/android/{claim}-logcat.log
```

Also save an unfiltered `logcat -d -b crash` per flow: a crash in another process can still be caused by the change.

## Drive and assert

Launch with `adb shell am start -n <package>/<activity>` or a deep link (`am start -a android.intent.action.VIEW -d <uri>`). Find elements by dumping the hierarchy (`adb shell uiautomator dump /sdcard/ui.xml` then pull it) and tap their bounds' centre with `adb shell input tap x y`; type with `input text`, navigate with `input keyevent`. Assert against the dumped hierarchy (text present, enabled state), not only against the screenshot.

Screenshot each meaningful state: `adb -s $S exec-out screencap -p > {run}/android/{claim}-{nn}-{slug}.png`.

## Also check

- Rotation (`adb shell settings put system user_rotation 1`) and process death (`adb shell am kill <package>` from the background, then return) for any screen with state.
- Dark mode (`adb shell cmd uimode night yes`) for any visual claim.
- Unit and instrumented tests the project defines for the touched modules.
