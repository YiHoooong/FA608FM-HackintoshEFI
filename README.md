# ASUS TUF A16 FA608FM Hackintosh EFI

macOS Tahoe 26.7.1 在 ASUS TUF A16 FA608FM 上的 OpenCore EFI 备份。

## 机器

| 项目 | 参数 |
|---|---|
| 型号 | ASUS TUF A16 FA608FM |
| CPU | AMD Ryzen 9 9955HX，16 核 / 32 线程 |
| GPU | NVIDIA GeForce RTX 5060 Laptop GPU，8GB（NullMoth 驱动） |
| 内存 | 16GB |
| 内屏 | 16" 2560×1600 @165Hz |
| Wi-Fi | MediaTek MT7922 / RZ616，`14c3:0616` |
| 蓝牙 | `0489:e0f6`（MT7922 combo） |
| 音频 | Realtek ALC256 |
| SMBIOS | MacPro7,1 |
| 系统 | macOS Tahoe **26.7.1 (25G241)** |
| 引导 | OpenCore（DEBUG build） |

## 工作

- CPU / GPU 加速：NullMoth 2.4.3，Metal 3
- 内屏 2560×1600 @165Hz
- HDMI 外接 **4K160**（HDMI 2.1；有时需要重启或重新插拔才出现）
- 音频：内置扬声器、内置麦克风、线路输入、3.5mm 耳机
  - ALC256，`layout-id 88`，AppleALC 1.9.9 + SimpleHDA 1.0.0
- Wi-Fi：MT7922 `14c3:0616`
  - AirportMtkWlan 1.5.0 + 0616 HAL patch（PR #4）
  - `SSDT-Disable_Network_GPP6.aml` 已禁用，`DisableIoMapper=true`
- 蓝牙：`0489:e0f6`
  - SimpleMtkBtFw / SimpleMtkBtPatcher 1.1.0 + BlueToolFixup 2.7.2
  - NVRAM: `bluetoothInternalControllerInfo` / `bluetoothExternalDongleFailed`
  - AirPods / A2DP / BLE 可用
- USB、有线网卡（RealtekRTL8111）、键盘
- 触控板：VoodooI2C；偶尔需要清 EC/冷启动才会 attach
- 睡眠/唤醒：`hibernatemode 0` 下可用；当前 `sleep=0` 关闭了自动睡眠

## 不工作 / 限制

- **内屏亮度调节**：NullMoth NVKMS 没注册背光
- **HDMI 音频**：NVIDIA HDMI audio 不工作；外接显示视频正常
- **AirDrop / Handoff / Continuity / AWDL**：MT7922 不支持
- **Wi-Fi**：WPA2 + 802.11n/ac；无 802.11ax、WPA3、AirDrop
- **华硕自适应亮度 / ALS**：EC 层行为，macOS 设置关不掉
  - `SSDT-ALS-OFF.aml` 只在 Darwin 下通过 ASUS WMI 关闭；复发时用 BIOS/MyASUS
- **关机后偶尔自动开机**：ACPI `_PTS`/`SPTS` 的 `SLPS=1` 问题
  - 已设 `womp 0`；BIOS 可关 ErP / Power On By PCI-E / USB Wake
  - 彻底修复需要改 `SPTS` 的 S5 分支（`SLPS=3`）的 ACPI 补丁
- **触控板**：VoodooInput/Precision 偶尔不 attach；清 EC/冷启动恢复
- **双系统 Windows**：从 macOS 切到 Windows 后可能因 EC/BIOS BootFailCount 或 Fast Startup 变慢
  - Windows 侧 `powercfg /h off`、`chkdsk C: /f`，再做一次 EC 复位
- **内置 USB-A（GL3523）**：持续 USB3 大写入可能把 hub 复位；大文件请用 MD202 直连 USB-C
- **HDMI 多显示器热插拔 / 第二个头**：NullMoth 限制

## EFI 内容

- `EFI/OC`：OpenCore（DEBUG）、ACPI、Kexts、Drivers、Resources、Tools
- ACPI：
  - `SSDT-ACFIX`（ASUS AC 检测修复）
  - `SSDT-ALS-OFF`（Darwin-only，关闭 ASUS ALS/自适应亮度）
  - `SSDT-USB-Reset`、`SSDT-USBX`
  - `SSDT-EC`、`SSDT-PLUG-ALT`、`SSDT-XOSI`
  - `SSDT-Disable_Network_GPP6`（已禁用，给 Wi-Fi 让路）
- 关键 config：
  - `DisableIoMapper=true`
  - `XhciPortLimit=false`
  - `ResizeAppleGpuBars=0`
  - `csr-active-config=0x0A43`
  - `SecureBootModel=Disabled`
  - boot-args: `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth -vi2c-force-polling amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0 npci=0x2000 -nvrmnobootscreen keepsyms=1 -v debug=0x100 gfxrst=4 nvrmacpibl=1`
- 完整 kext 列表：`Docs/kexts.txt`
- 自定义内容：
  - `Docs/SSDT-ALS-OFF.dsl`
  - `Docs/AirportMtkWlan-0616.patch`（RZ616 0616 HAL 补丁，对应 PR #4）
  - `Docs/ACFIX-README.md`

> **SMBIOS 序列号已脱敏（`REDACTED` / 全 0 UUID）**。使用前请用 GenSMBIOS/OCAT 生成自己的 `SystemSerialNumber`、`MLB`、`SystemUUID`、`ROM`，不要直接使用仓库里的占位值。

## BIOS 建议

- Above 4G Decoding：On
- CSM：Off；Secure Boot：Off
- XHCI Hand-off：On
- 关机自动开机：ErP Ready / Power On By PCI-E / USB Wake 关掉
- Resize BAR 按 NullMoth 的要求设置

## Credits

- OpenCore、Lilu、VirtualSMC、WhateverGreen、AppleALC、AMFIPass、NullMoth、USBToolBox、VoodooI2C、RealtekRTL8111、BlueToolFixup
- AirportMtkWlan：flxxxxddd / laobamac / pengubow（0616 patch / PR #4）
- SimpleMtkBtFw：flxxxxddd / laobamac
- SimpleHDA
- 各第三方 kext 保留其原始 license

## 说明

个人 EFI 备份，按现状提供，使用风险自负。
