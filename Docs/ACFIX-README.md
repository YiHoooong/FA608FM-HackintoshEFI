# ASUS FA608FM 黑苹果 —— AC 适配器识别修复记录

日期：2026-10-20
机器：ASUS TUF A16 FA608FM / Ryzen 9 9955HX / macOS 15.8.1 (24H32)

## 一、症状

- macOS 永远显示"使用电池"，不显示充电、不显示 AC
- `pmset -g batt` → `Now drawing from 'Battery Power'`
- `pmset -g adapter` → `No adapter attached.`
- `ioreg -rn AppleSmartBattery` → `ExternalConnected = No`
- 内核日志大量重复：
  - `ACPI Error ... [\_SB.ACAD._PSR] AE_AML_NO_RETURN_VALUE`
  - `ACPI Error ... [\_SB.ALIB] AE_AML_NO_RETURN_VALUE`

## 二、根因

1. `\_SB.ACAD._PSR` 里有一句 `ALIB (One, XX00)`。
2. `ALIB` 的 `Arg0 == One` 分支执行 `Local1 = A026 (Local0)`。
3. 固件里 `A026` 整段**没有 Return**，被 Apple ACPICA 判为
   `AE_AML_NO_RETURN_VALUE`，异常从 `A026 → ALIB → _PSR` 冒泡，
   `_PSR` 永远拿不到返回值。
4. `ACDC = Local0` 写在 `ALIB(...)` 之后，ALIB 一炸就执行不到，
   `ACDC` 恒为 `0xFF`，下次仍走 ALIB 分支 → 100% 必现。
5. Windows 的 ACPI 解释器容忍这种写法，所以 Windows 下正常。

## 三、修复（两步，已应用到主 EFI 和测试外置 EFI）

### 第 1 步：ACPI Patch，把原 `_PSR` 改名

OpenCore → `ACPI` → `Patch` 新增：

| 字段 | 值 |
|---|---|
| Comment | `_PSR to XPSR in ACAD (broken ASUS ALIB call)` |
| Enabled | true |
| Base | 空 |
| BaseSkip | 0 |
| Find | `5F 50 53 52` (`_PSR`) |
| Replace | `58 50 53 52` (`XPSR`) |
| Count | 1 |
| TableSignature | `DSDT` |
| Limit / Skip / Mask / OemTableId / TableLength | 0 / 0 / 空 / 空 / 0 |

说明：最初按文档使用 `Base = \_SB.ACAD`，在这台机器上实际未匹配；
DSDT 全表 `_PSR` 只出现一次，因此改为 **Base 留空 + Count=1 + TableSignature=DSDT**，
重启后确认生效。

### 第 2 步：加入 SSDT

- 文件：`EFI/OC/ACPI/SSDT-ACFIX.aml`
- `ACPI` → `Add` 新增，`Enabled = true`

该 SSDT 提供与原厂语义一致、但**不调用 ALIB** 的 `_PSR`：
ECOK 为真时加锁读 EC 的 `ACIN` / `NOAC`；
`NOAC == 1` 返回 0；否则返回 `ACIN`；ECOK 为假时返回 1。

## 四、验证

```bash
pmset -g batt
# 期望：Now drawing from 'AC Power'

pmset -g adapter
# 期望：显示 Wattage / AdapterID 等信息，不再是 "No adapter attached"

ioreg -rn AppleSmartBattery | grep -E "ExternalConnected|IsCharging|Amperage"
# 期望：ExternalConnected = Yes

sudo log show --last 5m --predicate 'process == "kernel"' 2>/dev/null | grep -c "_PSR"
# 期望：0
```

本次实测结果：`AC Power`、`ExternalConnected = Yes`、
适配器 `Watts = 60`（见下节说明）。

## 五、关于 60W 适配器读数

`pmset -g adapter` / `AdapterDetails` 显示：

```
Wattage = 60W
AdapterID = 256
FamilyCode = 0x00ba
Manufacturer = "ASUS "
```

这个瓦数来自 EC 上报的适配器信息，不是 `_PSR` 修复本身产生的。
请确认实际插的是随机附带的原装充电器还是 60W USB-C PD 充电器：

- 若实际是原装高功率适配器 → EC 上报值可能不准，只影响显示的瓦数/充电估算
- 若实际就是 60W PD 充电器 → 读数正确，但整机功率会有上限

它**不影响本次 AC 识别的修复**，也**不是 USB 大文件写入掉盘的原因**
（修复 AC 后，USB 写入仍在约 0.8–0.9 GB 处复位，问题另算）。

## 六、文件与备份

- 主 EFI（本文件所在 EFI）：
  - `EFI/OC/ACPI/SSDT-ACFIX.aml`
  - `EFI/OC/config.plist`（已加 Add + Patch）
- 主 EFI 修改前备份：
  - `~/Desktop/EFI-main-backup-20261020/config.plist.orig`
- 外置测试 EFI 各阶段备份：
  - `~/Desktop/EFI-external-backup-20261019/`
- 源文件、DSDT/ALIB 反汇编、iasl：
  - `~/Desktop/ACFIX-ACAD/`（README.md、SSDT-ACFIX.dsl/.aml、ref/）

## 七、回滚

1. `ACPI > Patch` 里禁用 `_PSR to XPSR in ACAD`
2. `ACPI > Add` 里禁用 `SSDT-ACFIX.aml`
3. 或直接用备份的 `config.plist.orig` 覆盖回去
4. 重启

## 八、备注

- 不要换成 `ACPIBatteryManager`；继续使用 `SMCBatteryManager`。
- 曾尝试给 `_PSR` 补丁加 `Base = \_SB.ACAD`，在这台机器上未匹配；
  当前可用的写法是 Base 留空 + `Count=1` + `TableSignature=DSDT`。
- USB 大文件写入掉盘是独立问题：UAS/BOT、固件 1.35.6、
  USBMap/RHUB、IOPCIFamily 补丁、AC 修复均已验证，仍会在
  约 0.8–0.9 GB 处设备自复位；Windows 下同一盘连续写 16 GB 正常。
