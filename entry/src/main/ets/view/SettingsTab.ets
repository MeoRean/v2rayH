import { common } from '@kit.AbilityKit';
import { AppState } from '../common/AppState';
import { AppTheme } from '../common/AppTheme';

const SET_NAV: number = 0;
const SET_BACKUP: number = 1;
const SET_ABOUT: number = 2;
const SET_APPEARANCE: number = 3;
const SET_LOGS: number = 4;

@Component
export struct SettingsTab {
  @ObjectLink app: AppState;
  @StorageProp('themeRev') themeRev: number = 0;
  @Prop @Watch('onResetTick') resetTick: number = 0;
  @StorageProp('topRectHeight') topRectPx: number = 0;
  @StorageProp('bottomRectHeight') bottomRectPx: number = 0;
  @StorageProp('wideMode') wideMode: boolean = false;
  @State sub: number = SET_NAV;
  @State xrayLog: string = '';
  @State vpnLog: string = '';

  private loadLogs(): void {
    this.xrayLog = this.app.readLogTail('xray_error.log', 12 * 1024);
    this.vpnLog = this.app.readLogTail('vpn.log', 12 * 1024);
  }

  private isWide(): boolean {
    return this.wideMode;
  }

  onResetTick(): void {
    this.sub = SET_NAV;
  }

  private subTitle(): string {
    if (this.sub === SET_APPEARANCE) {
      return '外观';
    }
    if (this.sub === SET_BACKUP) {
      return '备份与还原';
    }
    if (this.sub === SET_ABOUT) {
      return '关于';
    }
    if (this.sub === SET_LOGS) {
      return '连接日志';
    }
    return '设置';
  }

  @Builder
  topHeader() {
    Column() {
      Row() {
        if (this.sub !== SET_NAV) {
          Row() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(22)
              .fontColor([AppTheme.TEXT])
            Text('返回')
              .fontSize(15)
              .fontColor(AppTheme.TEXT)
              .margin({ left: 2 })
          }
          .height(36)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.sub = SET_NAV;
          })
        }

        Text(this.subTitle())
          .fontSize(this.sub === SET_NAV ? 28 : 15)
          .fontWeight(this.sub === SET_NAV ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(AppTheme.TEXT)
          .layoutWeight(1)
          .textAlign(this.sub === SET_NAV ? TextAlign.Start : TextAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.subDesc())
        .fontSize(12)
        .fontColor(AppTheme.TEXT_SUB)
        .margin({ top: 4 })
        .width('100%')
        .textAlign(this.sub === SET_NAV ? TextAlign.Start : TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  navRow(icon: Resource, title: string, desc: string, target: number) {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([AppTheme.PRIMARY])

      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT)
        Text(desc)
          .fontSize(11)
          .fontColor(AppTheme.TEXT_SUB)
          .margin({ top: 3 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(16)
        .fontColor([AppTheme.TEXT_WEAK])
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 15, bottom: 15 })
    .backgroundColor(AppTheme.CARD_BG)
    .borderRadius(AppTheme.CARD_RADIUS)
    .shadow({ radius: 14, color: '#10000000', offsetY: 3 })
    .onClick(() => {
      this.sub = target;
      if (target === SET_LOGS) {
        this.loadLogs();
      }
    })
  }

  @Builder
  logSection(title: string, body: string) {
    Column() {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT)
        .width('100%')
      if (body.length === 0) {
        Text('（空）')
          .fontSize(11)
          .fontColor(AppTheme.TEXT_WEAK)
          .margin({ top: 6 })
      } else {
        Text(body)
          .fontSize(11)
          .fontColor(AppTheme.TEXT_SUB)
          .fontFamily('monospace')
          .width('100%')
          .alignSelf(ItemAlign.Start)
          .copyOption(CopyOptions.LocalDevice)
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppTheme.CARD_BG)
    .borderRadius(AppTheme.CARD_RADIUS)
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 12 })
  }

  @Builder
  logsPage() {
    Scroll() {
      Column() {
        Row() {
          Text('连接失败时，这里能看到内核的真实报错')
            .fontSize(11)
            .fontColor(AppTheme.TEXT_WEAK)
            .layoutWeight(1)
          Button('清空')
            .fontSize(12)
            .height(30)
            .fontColor(AppTheme.DANGER)
            .backgroundColor(AppTheme.DANGER_SOFT)
            .borderRadius(15)
            .margin({ right: 8 })
            .onClick(() => {
              this.app.clearLogs();
              this.loadLogs();
            })
          Button('刷新')
            .fontSize(12)
            .height(30)
            .fontColor(AppTheme.PRIMARY)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .borderRadius(15)
            .onClick(() => {
              this.loadLogs();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 12 })

        this.logSection('xray_error.log（内核错误）', this.xrayLog)
        this.logSection('vpn.log（VPN 扩展）', this.vpnLog)

        Text('长按日志内容可全选复制。日志会随连接重试增长，这里仅显示末尾 12KB。')
          .fontSize(11)
          .fontColor(AppTheme.TEXT_WEAK)
          .width('100%')
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  navPage() {
    Column({ space: 12 }) {
      this.navRow($r('sys.symbol.paintbrush_pointed_filled_circle'), '外观', '深色模式与主题色 · ' + this.app.darkModeText(), SET_APPEARANCE)
      this.navRow($r('sys.symbol.doc'), '备份与还原', '导出 / 导入配置', SET_BACKUP)
      this.navRow($r('sys.symbol.info_circle'), '关于', '版本与内核信息', SET_ABOUT)
      this.navRow($r('sys.symbol.doc_plaintext'), '连接日志', '内核报错与 VPN 扩展日志', SET_LOGS)

      Column() {
        this.actionRow($r('sys.symbol.power'), '断开并退出', '停止 VPN 并结束应用（PC 上也可右键任务栏图标退出）', true, () => {
          this.confirmExit();
        })
      }
      .width('100%')
      .backgroundColor(AppTheme.CARD_BG)
      .borderRadius(AppTheme.CARD_RADIUS)
      .shadow({ radius: 14, color: '#10000000', offsetY: 3 })
      .margin({ top: 12 })
    }
    .width('100%')
    .margin({ top: 18 })
  }

  private confirmExit(): void {
    AlertDialog.show({
      title: '断开并退出',
      message: this.app.connected ? '将断开 VPN 连接并退出应用，后台代理会一并停止。' : '将退出应用（当前未连接 VPN）。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '退出',
        action: () => {
          this.exitApp();
        }
      }
    });
  }

  private exitApp(): void {
    this.app.disconnect();
    let ctx = this.getUIContext().getHostContext();
    if (ctx !== undefined) {
      try {
        (ctx as common.UIAbilityContext).terminateSelf().catch(() => {
        });
      } catch (e) {
        // 退出失败时保持运行，用户可从任务栏重试
      }
    }
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppTheme.TEXT)
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor(AppTheme.TEXT_SUB)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '62%' })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }

  @Builder
  dividerLine() {
    Divider()
      .strokeWidth(1)
      .color(AppTheme.DIVIDER)
      .margin({ left: 16, right: 16 })
  }

  @Builder
  aboutPage() {
    Column() {
      Column() {
        this.infoRow('应用名称', 'v2rayH')
        this.dividerLine()
        this.infoRow('版本', this.app.appVersion)
        this.dividerLine()
        this.infoRow('内核', 'libxray (Xray-core)')
        this.dividerLine()
        this.infoRow('内核版本', this.app.coreVersion.length > 0 ? this.app.coreVersion : '未知')
        this.dividerLine()
        this.infoRow('目标 SDK', this.app.apiLevel())
      }
      .width('100%')
      .backgroundColor(AppTheme.CARD_BG)
      .borderRadius(AppTheme.CARD_RADIUS)
      .margin({ top: 18 })
      .shadow({ radius: 14, color: '#10000000', offsetY: 3 })

      Text('内核版本取自 libxray.so 链接的 github.com/xtls/xray-core 模块版本（编译期写入，运行时为 Xray 26.3.27）。')
        .fontSize(11)
        .fontColor(AppTheme.TEXT_WEAK)
        .width('100%')
        .margin({ top: 12, left: 4 })
        .maxLines(3)

      Text('订阅与节点仅保存在本机，不会上传')
        .fontSize(11)
        .fontColor(AppTheme.TEXT_WEAK)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 12 })
    }
    .width('100%')
  }

  private subDesc(): string {
    if (this.sub === SET_APPEARANCE) {
      return '深色模式与主题色';
    }
    if (this.sub === SET_BACKUP) {
      return '导出 / 导入配置';
    }
    if (this.sub === SET_ABOUT) {
      return '版本与内核信息';
    }
    if (this.sub === SET_LOGS) {
      return '内核与 VPN 扩展运行日志';
    }
    return '备份数据与应用信息';
  }

  @Builder
  actionRow(icon: Resource, title: string, desc: string, danger: boolean, onTap: () => void) {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([danger ? AppTheme.DANGER : AppTheme.PRIMARY])

      Column() {
        Text(title)
          .fontSize(15)
          .fontColor(danger ? AppTheme.DANGER : AppTheme.TEXT)
        Text(desc)
          .fontSize(11)
          .fontColor(AppTheme.TEXT_SUB)
          .margin({ top: 2 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(15)
        .fontColor([AppTheme.TEXT_WEAK])
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      onTap();
    })
  }

  @Builder
  backupPage() {
    Column() {
      Column() {
        this.actionRow($r('sys.symbol.doc'), '备份到文件', '导出当前配置为 JSON 文件', false, () => {
          this.app.exportBackup();
        })
        Divider().strokeWidth(1).color(AppTheme.DIVIDER).margin({ left: 16, right: 16 })
        this.actionRow($r('sys.symbol.doc_plaintext'), '从文件还原', '选择备份文件并覆盖当前配置', false, () => {
          this.app.importBackup();
        })
        if (this.app.hasLocalSnapshot()) {
          Divider().strokeWidth(1).color(AppTheme.DIVIDER).margin({ left: 16, right: 16 })
          this.actionRow($r('sys.symbol.arrow_counterclockwise'), '还原本地快照', '使用最近一次导出的本机快照', false, () => {
            this.app.restoreSnapshot();
          })
        }
      }
      .width('100%')
      .backgroundColor(AppTheme.CARD_BG)
      .borderRadius(AppTheme.CARD_RADIUS)
      .margin({ top: 18 })
      .shadow({ radius: 14, color: '#10000000', offsetY: 3 })

      Text('备份包含订阅分组、节点、路由与资源地址；还原后会覆盖当前配置。')
        .fontSize(11)
        .fontColor(AppTheme.TEXT_WEAK)
        .width('100%')
        .margin({ top: 12, left: 4 })
        .maxLines(3)

      if (this.app.status.length > 0) {
        Text(this.app.status)
          .fontSize(11)
          .fontColor(AppTheme.PRIMARY)
          .width('100%')
          .margin({ top: 8, left: 4 })
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      Column() {
        this.actionRow($r('sys.symbol.trash'), '清空本地节点与订阅', '删除本机保存的全部节点，不可恢复', true, () => {
          this.app.clearAll();
        })
      }
      .width('100%')
      .backgroundColor(AppTheme.CARD_BG)
      .borderRadius(AppTheme.CARD_RADIUS)
      .margin({ top: 16 })
      .shadow({ radius: 14, color: '#10000000', offsetY: 3 })
    }
    .width('100%')
  }
  @Builder
  appearancePage() {
    Column() {
      Column() {
        Text('深色模式')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT)
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          SetChoiceChip({ label: '跟随系统', active: this.app.darkMode === 0, onPick: () => {
            this.app.setDarkMode(0);
          } })
          SetChoiceChip({ label: '浅色', active: this.app.darkMode === 1, onPick: () => {
            this.app.setDarkMode(1);
          } })
          SetChoiceChip({ label: '深色', active: this.app.darkMode === 2, onPick: () => {
            this.app.setDarkMode(2);
          } })
        }
        .width('100%')
        .margin({ top: 4 })

        Divider()
          .strokeWidth(1)
          .color(AppTheme.DIVIDER)
          .margin({ top: 14, bottom: 14 })

        Text('主题色')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT)
          .width('100%')
        Row() {
          SetAccentDot({ accentColor: '#0a59f7', selected: this.app.accentIndex === 0, onPick: () => {
            this.app.setAccent(0);
          } })
          SetAccentDot({ accentColor: '#34c759', selected: this.app.accentIndex === 1, onPick: () => {
            this.app.setAccent(1);
          } })
          SetAccentDot({ accentColor: '#7b61ff', selected: this.app.accentIndex === 2, onPick: () => {
            this.app.setAccent(2);
          } })
          SetAccentDot({ accentColor: '#ff8a00', selected: this.app.accentIndex === 3, onPick: () => {
            this.app.setAccent(3);
          } })
          SetAccentDot({ accentColor: '#ff3b30', selected: this.app.accentIndex === 4, onPick: () => {
            this.app.setAccent(4);
          } })
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppTheme.CARD_BG)
      .borderRadius(AppTheme.CARD_RADIUS)
      .margin({ top: 18 })
      .shadow({ radius: 14, color: '#10000000', offsetY: 3 })

      Text('主题色用于按钮、选中态与强调文字；切换深色模式会同时替换整体配色。')
        .fontSize(11)
        .fontColor(AppTheme.TEXT_WEAK)
        .width('100%')
        .margin({ top: 12, left: 4 })
        .maxLines(3)
    }
    .width('100%')
  }

  build() {
    Column() {
      this.topHeader()

      if (this.sub === SET_BACKUP) {
        this.backupPage()
      } else if (this.sub === SET_ABOUT) {
        this.aboutPage()
      } else if (this.sub === SET_APPEARANCE) {
        this.appearancePage()
      } else if (this.sub === SET_LOGS) {
        this.logsPage()
      } else {
        this.navPage()
        Blank()
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: AppTheme.PAGE_GAP,
      right: AppTheme.PAGE_GAP,
      top: px2vp(this.topRectPx) + 8,
      bottom: this.isWide() ? 20 : px2vp(this.bottomRectPx) + AppTheme.BAR_RESERVE
    })
  }
}

@Component
struct SetChoiceChip {
  label: string = '';
  @Prop active: boolean = false;
  onPick: () => void = () => {};

  build() {
    Text(this.label)
      .fontSize(12)
      .fontColor(this.active ? Color.White : AppTheme.TEXT)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(this.active ? AppTheme.PRIMARY : AppTheme.CHIP_BG)
      .borderRadius(100)
      .margin({ right: 8, top: 6 })
      .onClick(() => {
        this.onPick();
      })
  }
}
@Component
struct SetAccentDot {
  accentColor: string = '';
  @Prop selected: boolean = false;
  onPick: () => void = () => {};

  build() {
    Stack() {
      Column()
        .width(26)
        .height(26)
        .backgroundColor(this.accentColor)
        .borderRadius(13)
    }
    .width(38)
    .height(38)
    .borderRadius(19)
    .border({ width: 2, color: this.selected ? this.accentColor : Color.Transparent })
    .margin({ right: 10 })
    .onClick(() => {
      this.onPick();
    })
  }
}