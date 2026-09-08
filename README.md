#


[中文](https://github.com/MindShow/USBDisplay/blob/main/说明.md) | [English](https://github.com/MindShow/USBDisplay/blob/main/README.md)


## linux source code

+ [Linux source code](http://www.macrosilicon.com:9080/download/USBDisplay/Linux/)



## Install Guide

1. Turn off/uninstall antivirus software
2. Plug the USB Display dongle
3. Run the driver setup software in USB Mass Storage Device
  
    |  OS   | Driver|
    |-------|-------|
    |Windows| xx.exe|
    |MacOS  | xx.dmg|
    |Android| xx.apk|
    |Linux  | ms912x driver (DKMS) — see [Linux](#linux) |

4. Reboot the systerm

## Drivers Download

### USB Display Driver For Win7/8/10/11 x86/x64/ARM

#### Latest Release

+ [MSDisplay_Windows_V2.0.1.7.3.exe](https://github.com/MindShow/USBDisplay/blob/main/WinDows/MSDisplay_Windows_V2.0.1.7.3.exe)

#### Older releases

+ [MSDisplay_MultiDev_v1.0.0.18.0.exe](https://github.com/MindShow/USBDisplay/blob/main/WinDows/MSDisplay_MultiDev_v1.0.0.18.0.exe)
+ [MSDisplay_MultiDev_v1.0.1.60.exe](https://github.com/MindShow/USBDisplay/blob/main/WinDows/MSDisplay_MultiDev_v1.0.1.60.exe)
+ [MSDisplay_MultiDev_v1.0.1.4.exe](https://github.com/MindShow/USBDisplay/blob/main/WinDows/MSDisplay_MultiDev_v1.0.1.4.exe)
+ [MSDisplay_MultiDev_v1.0.1.3.exe]([./WinDows/MSDisplay_MultiDev_v1.0.1.3.exe](https://github.com/MindShow/USBDisplay/blob/main/WinDows/MSDisplay_MultiDev_v1.0.1.3.exe))

### USB Display Driver For WinXP

#### Latest Release

+ [MSDisplay_v1.0.0.0_XP.exe](https://github.com/MindShow/USBDisplay/blob/main/WinXP/MSDisplay_v1.0.0.0_XP.exe)

#### Older releases

### USB Display Driver For MacOS x86/x64/ARM

#### Latest Release

+ [MSDisplay_MacOS_V2.0.0.1_20220606.dmg](https://github.com/MindShow/USBDisplay/blob/main/MacOS/MSDisplay_MacOS_V2.0.0.1_20220606.dmg)

#### Older releases

+ [MSDisplay_MacOS_v1.0.2b_20201125.dmg](https://github.com/MindShow/USBDisplay/blob/main/MacOS/MSDisplay_MacOS_v1.0.2b_20201125A.dmg)
+ [MSDisplay_MacOS_v1.0.2_20200926.dmg](https://github.com/MindShow/USBDisplay/blob/main/MacOS/MSDisplay_MacOS_v1.0.2_20200926.dmg)
+ [MSDisplay_MacOS_v1.0.1.0_20200309.dmg]([./MacOS/MSDisplay_MacOS_v1.0.1.0_20200309.dmg](https://github.com/MindShow/USBDisplay/blob/main/MacOS/MSDisplay_MacOS_v1.0.1.0_20200309.dmg))

### USB Display Driver For Android

#### Latest Release

+ [MSDisplay_Android_V2.0.1.3.apk](https://github.com/MindShow/USBDisplay/blob/main/Android/MSDisplay_Android_V2.0.1.3.apk)

#### Older releases

+ [MSDisplay_Android_v2.0.0.3.apk](https://github.com/MindShow/USBDisplay/blob/main/Android/MSDisplay_Android_v2.0.0.3.apk)
+ [MS9120_V1.0.1.6_release.apk](https://github.com/MindShow/USBDisplay/blob/main/Android/MS9120_V1.0.1.6_release.apk)

## Linux

### Driver compatibility

The official MacroSilicon Linux driver only supports the **MS913x** chips
(VID `0x345f`, PID `0x9132/0x9133/0x9135`). It will **not** bind to **MS912x**
adapters (VID/PID `534d:6021`, `534d:0821` — often labeled "VGA Display
Adapter" / "USB to VGA/HDMI"). For those, use the open-source **ms912x** DRM
driver; this fork keeps the Linux setup documented and verified below.

| lsusb ID           | Chip   | Driver                                  |
|--------------------|--------|-----------------------------------------|
| `345f:9132/9133/9135` | MS913x | Official MacroSilicon DRM driver        |
| `534d:6021`/`534d:0821` | MS912x | [ms912x](https://github.com/rhgndf/ms912x) (open source) |

### Reproducible install (Linux)

The script [Linux/install-ms912x.sh](Linux/install-ms912x.sh) automates the
whole setup and is safe to re-run on any other host: it installs the build
prerequisites, picks the driver branch matching the running kernel, registers
the module with DKMS (survives kernel upgrades), loads it, and enables it at
boot. It is idempotent — running it again only refreshes the driver.

```bash
git clone https://github.com/MindShow/USBDisplay.git
cd USBDisplay
sudo ./Linux/install-ms912x.sh
```

It detects the adapter on the bus and warns if an unsupported MS913x chip is
present. After it finishes, configure the new output in *Settings → Displays*.

### Manual install on Arch Linux

1. Install the build prerequisites:

   ```bash
   sudo pacman -S linux-headers dkms base-devel git
   ```

2. Clone the driver and pick the branch matching your kernel:

   ```bash
   git clone https://github.com/rhgndf/ms912x.git
   cd ms912x
   git checkout kernel-<YOUR_KERNEL>    # e.g. kernel-7.2 for kernel 7.2.x
   ```

3. Build and register with DKMS (survives kernel upgrades):

   ```bash
   sudo dkms install .
   dkms status                          # expect: ms912x/0.1, <kernel>, x86_64: installed
   ```

4. Load the module and enable it at boot:

   ```bash
   sudo modprobe ms912x
   echo "ms912x" | sudo tee /etc/modules-load.d/ms912x.conf
   ```

5. Open *Settings → Displays* and arrange the new output (mirror or extend).

> The DRM driver works with both X11 and Wayland compositors. On GNOME Wayland
> the new output is detected automatically (re-login if it does not appear).

### Troubleshooting

**Glitches in extended mode (none in mirror mode).** The driver can only
update the framebuffer in multiples of 16 pixels. Resolutions that are not a
multiple of 16 (e.g. 1366×768) show artifacts on the external display. Set the
external display to a multiple of 16, e.g. **1280×720@60**.

**Mouse cursor invisible on the external display (GNOME Wayland).** The ms912x
driver exposes no cursor plane, so the compositor must draw the cursor
itself. If it does not appear, either change the cursor size (Accessibility →
Cursor) to force a software cursor, or use the **GNOME on Xorg** session
(GNOME 46+ no longer ships it; create `/usr/share/xsessions/gnome-xorg.desktop`).

**Module loads but no signal.** Check `dmesg | grep ms912x`, unplug/replug the
adapter, and on X11 verify the output with `xrandr --listproviders`.

## FAQ

1. The driver was killd by antivirus software

    ``` txt
    Add the file into the antivirus software 'Exceptions' or 'Trust' list
    ```

2. Is it support Win7?

    ``` txt
    Need Win7 SP1 or above
    ```

3. Black screen with mouse only with MacOS?

    ``` txt
    System Preferences -> Security & Privacy -> Privacy -> Screen Recording,
      find screen_capturee_msdisply and check that
    ```

4. Portrait mode doesn't work on WIndows?

    ``` txt
    Can not support
    ```

## Support

If there is an exception in the program, feedback a copy of the file WinUsbDisplay.log

1. The default location of this file

    ``` bat
    "C:\Users\%yourUserName%\AppData\Roaming\WinUsbDisplay\WinUsbDisplay.log"
    ```

2. you can also find the file of ```WinUsbDisplay.log``` by running ```logpath.bat```.

&nbsp;
&nbsp;
&nbsp;
### <center>[Technical Support By UltraSemi](http://www.ultrasemi.com)</center>
