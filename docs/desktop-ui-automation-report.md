# Windows 桌面端 UI 自动化验收

验收日期：2026-07-29

## 构建产物

- Flutter SDK：`F:\flutter-sdk\flutter\flutter\bin\flutter.bat`
- Pub 缓存：`F:\DevCache\pub`
- Windows release：`app\build\windows\x64\runner\Release\xiguang.exe`
- 后端地址：`http://127.0.0.1:8088/api/v1`

构建命令：

```powershell
flutter build windows --release `
  --dart-define=API_BASE_URL=http://127.0.0.1:8088/api/v1
```

## 实际桌面操作

已在 Windows release 中完成以下真实操作：

- 退出登录、确认退出、重新输入测试账号并登录。
- 切换“隙 / 线 / 屿 / 我的”四个底部入口。
- 查看时间河流真实光片列表和小宇宙岛屿加载。
- 滚动“我的”页面并打开“隙光会员”。
- 确认支付关闭时没有可点击的购买入口。

实际操作发现并修复：

- 微光会员 Hero 使用白字叠加浅色渐变，日间模式不可读。
- 支付渠道关闭时套餐卡把固定目录价格一并隐藏。

## 无前台自动化

为避免占用用户的鼠标、键盘和桌面，后续使用 Flutter `WidgetTester`
直接驱动 Widget 树。桌面会员流程使用 `1268 x 714` 视口，覆盖：

- 微光 Hero 标题使用深色前景。
- 免费档显示 `1GB 永久空间`。
- 星光显示 `¥12/月付 · ¥98/年付`。
- 星河显示 `¥28/月付 · ¥218/年付`。
- 两个付费档在渠道关闭时显示“支付渠道暂未开放”。
- 年付 7 天试用和自动续费说明存在。
- 页面滚动后无布局异常或测试异常。

截图证据：

- `app\test\goldens\membership_desktop_top.png`
- `app\test\goldens\membership_desktop_catalog.png`

自动化命令：

```powershell
flutter test test/ui test/features/membership
```

结果：42 项测试全部通过。
