# Protocol: what has been verified

[Version française](protocole.md)

Recorded with `tools/probe.sh` and `tools/app.sh --verify` on a CMF Headphone Pro (model B175, firmware 1.0.1.49) connected to a Mac running macOS 26.3.

The frame format and the command numbers come from the community's documentation of the protocol, in particular [Ear (web)](https://github.com/radiance-project/ear-web) and [BudsLink](https://github.com/maniacx/BudsLink). No code from these projects is included here.

## Link

- Bluetooth Classic, RFCOMM, service `aeac4a03-dff5-498f-843a-34487cf133eb`.
- On this headset the service is on channel 28. The number is read from the services the device declares (SDP); it must not be hard-coded.
- The serial port macOS creates by itself (`/dev/cu.CMFHeadphonePro`) points to another service (channel 12, "TOTA"): it does not answer the protocol.
- macOS only grants Bluetooth to an application whose `Info.plist` carries `NSBluetoothAlwaysUsageDescription`. A plain executable started from a terminal is killed at the first call; hence the small `.app` bundle made by `tools/probe.sh`.

## Frame

```
55 60 01 | command (2 bytes, little-endian) | length (2 bytes) | sequence | payload | CRC16
```

- Modbus-style CRC16 (initial value `0xFFFF`, reflected polynomial `0xA001`) over everything before it, low byte first.
- In a reply, the CRC is only present when bit `0x20` of the control word (bytes 1 and 2) is set.
- Reads: `0xC0xx`. Writes: `0xF0xx`. Replies: `0x40xx`. Unsolicited notifications: `0xE0xx`.

## Confirmed reads

| Request | Reply | Payload received | Meaning |
|---|---|---|---|
| `C007` battery | `4007` | `01 06 28` | 1 item; `06` = headset; `28` = 40% (bit `0x80` = charging) |
| `C042` firmware | `4042` | `31 2e 30 2e 31 2e 34 39` | ASCII text "1.0.1.49" |
| `C006` identity | `4006` | lines of `type,rank,value` | rank 2 = firmware, rank 4 = serial number, rank 6 = address |
| `C01E` noise control | `401E` | `01 01 00 02 01 00` | byte 1 = mode: `01` high, `02` mid, `03` low, `04` adaptive, `05` off, `07` transparency |
| `C01F` equaliser | `401F` | `00` | not used on this model, which goes through `C050` |
| `C050` listening mode | `4050` | `03` | equaliser preset, see below; `03` = Pop, as the mobile app showed |
| `C044` custom equaliser | `4044` | 109 bytes | zeros when no curve is stored; format below |
| `C04F` spatial audio | `404F` | `02 00` | mode, head tracking; `02 00` = Concert, as the mobile app showed |
| `C041` low lag mode | `4041` | `00` or `02` | `01` = on; `02` = off after a write, `00` while nothing has been set |
| `C04E` bass enhancement | `404E` | `00 00` | enabled, level (the level shown is half the byte on neighbouring models) |
| `C018` controls | `4018` | `04` then 4 × 4 bytes | device, button, gesture, action |
| `C027` dual connection | `4027` | `01` | `01` = on |
| `C029` codec | `4029` | `00` | `00` AAC, `01` LHDC, `02` LDAC |
| `C05A` sound profile | `405A` | `00` | `01` = personal profile on |

### Equaliser presets

| Byte | Preset |
|---|---|
| `00` | Dirac Opteo (according to Ear (web)) |
| `01` | Rock |
| `02` | Electronic |
| `03` | Pop |
| `04` | Enhance vocals |
| `05` | Classical |
| `06` | Custom |

### Spatial audio

| Bytes | Mode |
|---|---|
| `00 00` | Off |
| `01 00` | Fixed |
| `01 01` | Head tracking |
| `02 00` | Concert |
| `03 00` | Cinema |
| `04 00` | Game |

### Controls

The four mappings received match what the mobile app showed:

| Bytes | Meaning |
|---|---|
| `06 0a 01 0b` | button, single press → voice assistant |
| `06 0a 07 01` | button, press and hold → no action |
| `06 05 01 23` | slider → bass |
| `06 01 07 16` | roller, press and hold → noise control |

Gesture: `01` single press or slide, `02` double, `03` triple, `07` press and hold, `09` double press and hold. Button: `0a` button, `05` slider, `01` roller (or the stem of an earbud).

Actions: `01` none, `02` play or pause, `08` previous track, `09` next track, `0b` voice assistant, `0a` `14` `15` `16` noise control (depending on the modes it cycles through), `12` volume up, `13` volume down, `18` camera shutter, `1b` spatial audio, `1d` microphone on or off, `1f` Essential News, `20` Channel Hop, `21` Essential Space, `22` equaliser preset, `23` bass, `24` treble. The slider only accepts `23` and `24`, the roller only noise control or nothing.

## Received without asking

When the channel opens the headset sends `4041` (low lag), `E003` (noise control), and `7C09` and `E019`, not identified. After the battery read it also sends `E001` (same content as `4007`), and again whenever the level changes.

## Writes

Confirmed on 12 October 2026 with `tools/app.sh --verify`: each value was written, read back from the device's reply, then restored. The device acknowledges with an empty `70xx` frame (same number as the write, top bit cleared).

| Command | Payload | Effect | Status |
|---|---|---|---|
| `F00F` | `01`, mode, `00` | noise control (same values as the read); the device also sends `E003` | confirmed |
| `F01D` | preset, `00` | equaliser | confirmed |
| `F052` | mode, head tracking | spatial audio | confirmed |
| `F040` | `01 00` on, `02 00` off | low lag mode; the read then returns `01` or `02` | confirmed |
| `F003` | `01`, device, button, gesture, action | controls, one at a time | confirmed |
| `F041` | see below | custom equaliser | confirmed |
| `F01A` | `01` or `00` | dual connection | works in use, from the app |
| `F01B` | `01` connect or `00` disconnect, then the 6 address bytes | one of the dual connection's devices | works in use, from the app |
| `F002` | headphones: `06`, then `01` or `00`; earbuds: `02` left or `03` right, then `01` or `00`; Ear (1): `01` or `00` alone | rings the device to find it | works in use on the headset (`06 01`); earbud formats not tried |
| `F01C` | codec number | codec (the headset may restart) | not tried |
| `F051` | enabled, level | bass enhancement (levels `02` to `0A` in steps of 2, or `00` `05` `0A` on three-step models) | not tried, absent from the CMF Headphone Pro |
| `F004` | `00 00`, then `01` or `00` | wear detection (read `C00E`, reply `400E`, state in the third byte) | not tried, absent from the CMF Headphone Pro |
| `F05C` | `01` or `00` | personal sound profile | not tried |

### Custom equaliser

Format described by Ear (web), confirmed on the device: the curve written is read back identical. Numbers are 32-bit floats, little-endian.

```
number of filters | overall gain | for each filter: type, gain (dB), frequency (Hz), quality | 3 zero bytes per filter
```

For this model, three filters in this order: peak (`01`) at 980 Hz, Q 0.7 for the mids; high shelf (`02`) at 3,500 Hz, Q 1.0 for the treble; low shelf (`00`) at 140 Hz, Q 0.8 for the bass. The overall gain is the opposite of the largest boost, to avoid clipping. A headset with no stored curve answers `C044` with 109 zero bytes; with a curve, the reply keeps 109 bytes: the filters first, two unidentified bytes after them, then zeros.

## Dual connection

`C028` followed by one byte (the number of devices already received) returns a page of the list in `4028`: two header bytes, the number of devices in the page, then for each one a status byte (high nibble: this is the device asking; low nibble: it is connected), six address bytes, the length of the name and the name. Ask again as long as a page brings something new. Format described by Ear (web); on the device the read returned four devices in one 90-byte page, and the next request returned the same page.

`E00E` (one status byte, six address bytes, one byte) arrives when a device connects or leaves: the app then reads the list again. Probable interpretation, from the shape of the frame.

## What each model can do

The app only offers a setting when the model has it. The table (`Capabilities`, in `Sources/NothingKit/Catalog.swift`) follows the configuration the official app carries for each model: noise control, spatial audio modes, bass enhancement and its steps, wear detection, ring, dual connection and whether changing it restarts the device. For the CMF Headphone Pro: Concert and Cinema spatial audio, ring, dual connection without a restart; neither bass enhancement (the energy slider stands in for it) nor wear detection. BudsLink lists both for this model, wrongly according to the official configuration and to the `00 00` reply to `C04E`.

`Model.actions(for:)`, in the same file, gives the actions each gesture accepts on each model, from the same configuration.

## Still to establish

- Automatic power-off (`powerOffTime` in the official configuration): command unknown, absent from both Ear (web) and BudsLink. It would have to be captured from a phone's Bluetooth log while changing that setting in the official app.
- Earbud gestures: the app shows the ones the device declares (`C018`) and offers the actions of the official configuration, but none has been written to real earbuds.
- The meaning of `7C09`, `E019` and `E002` (3 bytes), received without asking.
- Sound profile calibration, which at Nothing relies on a third-party SDK (Audiodo).
