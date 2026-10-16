# HazeFocus 签名与公证

普通本地构建仍使用临时签名。正式发行需要钥匙串中带私钥的 **Developer ID Application** 证书，以及有公证权限的开发者账户；Apple Development 证书不能代替发行证书。

先在本机终端保存公证凭据，按安全提示输入 App 专用密码。不要将密码或 API 私钥写入仓库、脚本或聊天：

```bash
xcrun notarytool store-credentials HazeFocus-notary \
  --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID
```

随后运行：

```bash
SIGNING_IDENTITY='Developer ID Application: YOUR_NAME (YOUR_TEAM_ID)' \
NOTARY_PROFILE='HazeFocus-notary' \
bash scripts/notarize.sh
```

如果凭据保存在非默认钥匙串，可额外设置 `NOTARY_KEYCHAIN` 路径。脚本先验证本机签名证书和公证凭据，再构建 Universal 应用，使用 Hardened Runtime 和安全时间戳签名。应用 ZIP 经 Apple 接受后，脚本为应用装订票据，再生成、签名、公证和装订 DMG，最后验证 Gatekeeper、票据、磁盘映像和 SHA-256。

提交 ID、Apple 日志和状态保存在被 Git 忽略的 `artifacts/notarization/` 中。等待超时不代表提交失败；使用日志中的提交 ID 执行 `xcrun notarytool info` 或 `wait` 查询原任务，避免重复提交。只有 Apple 状态为 `Accepted` 且后续验证通过，才能将网站状态更新为“已公证”。

公证成功前，保留线上下载和“未公证”说明。重新签名可能导致辅助功能授权需要重新授予。

参考：[Apple 公证文档](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)。
