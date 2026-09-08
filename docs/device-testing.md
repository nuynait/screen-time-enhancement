# Physical-device acceptance

Simulator UI tests use an explicitly labeled preview. They never assert real blocking or monitor registration. A separate simulator test checks Apple's schedule date resolution without requesting Screen Time access.

## Prerequisites

- A compatible Xcode installation that can run on the connected iPhone.
- A developer team authorized by the user, with Family Controls and App Groups in the provisioning profiles of **all four** targets.
- An iPhone with two nonessential apps installed, such as Rednote and Bilibili.
- Re-run `generate.sh` after changing SDKs. Check its handoff message.

## Checklist

| Check | Expected result | Status |
| --- | --- | --- |
| Authorize | Individual Screen Time authorization succeeds | Not run |
| Deny authorization | Clear setup state; no false claim of protection | Not run |
| Pick two individual apps | Both appear with Apple's names/icons and are shielded | Not run |
| Pick category/domain | Save fails visibly, previous selection remains | Not run |
| Open a protected app | Native shield appears before using its content | Not run |
| Direct handoff, compatible SDK + iOS 26.5+ | Solve button opens Gate for exactly the tapped app | Not run |
| Fallback handoff | Prepare closes app; notification tap opens its challenge | Not run |
| Notifications denied | Opening Gate manually still shows prepared challenge | Not run |
| Wrong answer | Shield remains; challenge explains retry | Not run |
| Cancel or swipe challenge away | No grant or unshield operation occurs | Not run |
| Change Settings → Unlock time, then relaunch Gate | Choice persists; a new calculation offers the chosen duration | Not run |
| Correct answer | Only the chosen app opens; other app stays blocked | Not run |
| Change duration during an active window | Its end time remains unchanged; a new calculation uses the new preference | Not run |
| Leave/reopen unlocked app | No new challenge during its current window | Not run |
| Remain in target for 1-minute and 5-minute windows | Shield returns at each chosen expiry without foregrounding Gate | Not run |
| Remain in target for a default 15-minute window | Shield returns without foregrounding Gate | Not run |
| Use a 30-minute or 60-minute window | Countdown and background expiry match the selected duration | Not run |
| Force-quit Gate after unlocking | System extension still reapplies shield after expiry | Not run |
| Lock phone across expiry | App is shielded on resuming device use | Not run |
| Close/relaunch Gate during a window | Remaining time survives; no timer reset | Not run |
| Lock now | Immediate shield; late old callback does not affect a later grant | Not run |
| Unlock both apps at different times | Each expires independently | Not run |
| Remove selected app | Its shield is removed and old grants/monitors are pruned | Not run |
| Revoke permission | Gate reports access needed instead of claiming protection | Not run |
| Midnight / timezone change | Stored expiration stays absolute; no day-long unlock | Not run |
| Reboot during unlock | Observe callback behavior and confirm expired grants relock | Not run |

Record actual times for expiry, including any OS callback delay. Apple's minimum **monitor interval** is 15 minutes. For shorter unlocks, Gate pads the interval's start into the past while retaining the chosen expiry; the app only unshields after the correct answer and successful registration. The date-resolution test cannot prove that the OS delivers those callbacks on a phone. Verify short windows explicitly. If the expiry callback is unreliable on the target OS, investigate before relying on Gate.

## Verification recorded on 2026-09-08

- Xcode 26.3 / iOS 26.2 SDK built the notification/manual handoff.
- All 13 core tests, 3 simulator state/API tests, and 3 simulator UI flows passed, including configurable duration and old-state compatibility.
- A signed Debug build succeeded with automatic development provisioning. The app and all three extensions contained Family Controls and a matching App Group in both signatures and provisioning profiles.
- Physical-device enforcement has not been verified. The checklist above remains open.

Use your own developer team, bundle identifier, and App Group in the ignored `Config/Local.xcconfig`. If Xcode cannot mount a phone's developer image, resolve its device-support setup before attempting the checklist. Record technical environment details and observed timings when testing; keep account identifiers and device UDIDs in local notes rather than public reports.
