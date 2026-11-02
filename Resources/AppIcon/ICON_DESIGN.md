# Looma 应用图标

- 源图：`AppIcon.png`（1254 × 1254，带透明圆角）
- 应用包图标：`AppIcon.icns`
- 图案：根据用户提供的黑猫照片制作的 Q 版头像，浅奶油色底、黄绿色眼睛、白色胡须。
- 构建时 `scripts/generate-app-icon.sh` 从源图生成各尺寸 iconset 和 icns。

运行时使用应用包里的 `AppIcon.icns`，不要再手动设置 `NSApplication.shared.applicationIconImage`。
