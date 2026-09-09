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
| First notification request after Screen Time setup | System prompt appears once on notification-based builds; direct-opening builds do not request it | Not run |
| Allow notification permission | Home's Opening a calculation block disappears | Not run |
| Decline first notification request | Guidance remains; no immediate Settings redirect or extra error alert | Not run |
| Tap Allow challenge notifications after denial | Opens Gate's notification settings instead of repeating the system prompt | Not run |
| Turn notifications off/on in Settings, then return | Home guidance appears/disappears to match the latest permission | Not run |
| Wrong answer | Shield remains; challenge explains retry | Not run |
| Set and confirm emergency passcode, then relaunch Gate | Passcode stays configured and works; code is never displayed | Not run |
| Wrong emergency code or cancel entry | No app unlock or Settings access | Not run |
| Correct emergency code on an app challenge | Duration picker appears; the app remains blocked until Unlock app is confirmed | Not run |
| Confirm 15-minute or longer emergency window | Only that app opens for the selected duration; normal math preference is unchanged; shield returns after expiry | Not run |
| Choose Rest of today, quit Gate, and cross midnight | Only the selected app stays open until the captured local midnight, then relocks | Not run |
| Cancel or background the duration picker | No grant; reopening requires the code again | Not run |
| Open picker near midnight or across a daylight-saving transition | Choices respect the remaining day; at least 15 minutes; no rollover to another day without entering the code again | Not run |
| Emergency bypass on Settings or practice | No app grant is created or extended | Not run |
| Leave unfinished passcode entry and return | Input clears, calculation refreshes, same saved code still works | Not run |
| Change or remove emergency code | Current code required; old code stops working after change/removal | Not run |
| Leave an unfinished app, practice, or Settings calculation for Calculator, then return | Both numbers and the answer change; input clears; old answer is rejected; difficulty/duration stay the same | Not run |
| Leave a completed challenge and return | Success remains; an app window keeps its original expiry | Not run |
| Cancel or swipe challenge away | No grant or unshield operation occurs | Not run |
| Change Settings → Unlock time, then relaunch Gate | Choice persists; a new calculation offers the chosen duration | Not run |
| Open Settings, cancel or answer incorrectly | Current calculation is required; Settings stays closed; no app grant changes | Not run |
| Solve Settings gate, change difficulty, leave Settings or background Gate | Next Settings visit requires the updated calculation | Not run |
| Change operation and either digit count, then relaunch | Choices persist; new app and practice calculations match them | Not run |
| Solve addition, subtraction, multiplication, and division | Correct answer unlocks only the chosen app; subtraction is nonnegative and division has no remainder | Not run |
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
- All 13 core tests, 3 simulator state/API tests, and 4 simulator UI flows passed, including configurable duration, old-state compatibility, and notification permission/Settings handoff. The notification test also passed with Allow on a separate fresh install. The simulator opens Settings but does not expose per-app notification toggles.
- A signed Debug build succeeded with automatic development provisioning. The app and all three extensions contained Family Controls and a matching App Group in both signatures and provisioning profiles.
- Physical-device enforcement has not been verified. The checklist above remains open.

Use your own developer team, bundle identifier, and App Group in the ignored `Config/Local.xcconfig`. If Xcode cannot mount a phone's developer image, resolve its device-support setup before attempting the checklist. Record technical environment details and observed timings when testing; keep account identifiers and device UDIDs in local notes rather than public reports.


## Calculation choices and Settings gate verification

The calculation update passes 16 core tests and 12 distinct simulator state/UI tests (full suite plus targeted refinement runs). This includes current-rule Settings gating, wrong answers, cancellation, repeated visits, changed operation/digit sizes, background return, practice without app access, and saved preference compatibility. Light/dark and largest-text layouts were inspected. The final signed Debug iPhone build succeeds. These checks do not replace the physical-device rows above.


The foreground-refresh update passes **17 core tests and the full 13-test simulator suite**. Switching to the system Settings app and back verifies fresh operands/answers and cleared input for app, practice, and Settings calculations, rejection of the previous answer, and preservation of completed app windows. Calculator is absent from the tested simulator. The final signed Debug iPhone build passes; the physical-device checklist remains open.


## Emergency passcode verification

The emergency bypass update passes **20 core tests and 19 distinct simulator state/UI/app-hosted tests** across the suite and focused refinement/recovery runs. Tests cover confirmation, leading zeros, wrong/canceled entry, app/Settings/practice bypass, captured duration and per-app isolation, stale/duplicate session rejection, change/removal, background entry clearing, and Keychain persistence/protection attributes. Generic simulator signing with no developer team also passes the hosted checks. A simulator keyboard animation stall in an existing Settings test required restarting the simulator; the test then passed without an app-code workaround. Light/dark and largest-text screens were inspected, and the final signed Debug iPhone build succeeds. The physical-device checklist remains open.


## Emergency unlock duration verification

The duration update passes **24 core tests and 23 distinct simulator tests** across focused, regression, and visual-refinement runs. Coverage includes verification without granting access, explicit duration confirmation, cancellation and app switching, stale/duplicate authorization, independent math preferences, per-app isolation, local midnight, 23/25-hour daylight-saving days, the late-night 15-minute minimum, persisted expiry, and Device Activity schedule resolution. The largest-text test verifies the selected Today row and midnight preview after scrolling; it checks real onscreen bounds because XCTest reported an offscreen button as hittable. Light/dark and largest-text screenshots were inspected. The final signed Debug iPhone build of all four targets succeeds. Real shielding, extended windows, and midnight relocking still require the physical-device checks above.
