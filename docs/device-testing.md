# Physical-device acceptance

Simulator UI tests use an explicitly labeled preview. They never assert real blocking or scheduling.

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
| Correct answer | Only the chosen app opens; other app stays blocked | Not run |
| Leave/reopen unlocked app | No new challenge during its current window | Not run |
| Remain in target for full 15 minutes | Shield returns without foregrounding Gate | Not run |
| Force-quit Gate after unlocking | System extension still reapplies shield after expiry | Not run |
| Lock phone across expiry | App is shielded on resuming device use | Not run |
| Close/relaunch Gate during a window | Remaining time survives; no fresh 15-minute reset | Not run |
| Lock now | Immediate shield; late old callback does not affect a later grant | Not run |
| Unlock both apps at different times | Each expires independently | Not run |
| Remove selected app | Its shield is removed and old grants/monitors are pruned | Not run |
| Revoke permission | Gate reports access needed instead of claiming protection | Not run |
| Midnight / timezone change | Stored expiration stays absolute; no day-long unlock | Not run |
| Reboot during unlock | Observe callback behavior and confirm expired grants relock | Not run |

Record actual times for expiry, including any OS callback delay. Do not shorten the monitor schedule below 15 minutes to speed up this check: Apple rejects it. If the expiry callback is unreliable on the target OS, treat that as an implementation issue to investigate before relying on Gate, not a passed test.

## Verification recorded on 2026-09-08

- Xcode 26.3 / iOS 26.2 SDK built the notification/manual handoff.
- All 11 core tests and both simulator UI tests passed.
- A signed Debug build succeeded with automatic development provisioning. The app and all three extensions contained Family Controls and a matching App Group in both signatures and provisioning profiles.
- Physical-device enforcement has not been verified. The checklist above remains open.

Use your own developer team, bundle identifier, and App Group in the ignored `Config/Local.xcconfig`. If Xcode cannot mount a phone's developer image, resolve its device-support setup before attempting the checklist. Record technical environment details and observed timings when testing; keep account identifiers and device UDIDs in local notes rather than public reports.
