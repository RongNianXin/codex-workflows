# ChatGPT 网页版用户脚本

**简体中文** | [English](README.en.md)

这里收录适用于 ChatGPT 网页版的篡改猴用户脚本。

> [!IMPORTANT]
> Chrome 138 及以上版本需要打开 `chrome://extensions`，进入“篡改猴”的“详细信息”，开启“允许运行用户脚本”。Chrome 138 以下版本需要在扩展程序页面开启“开发者模式”。

![Chrome 扩展程序详情页中的“允许运行用户脚本”开关](<附图1 需要开启“允许用户运行脚本”.png>)

## 脚本列表

| 脚本 | 功能 | 安装 |
| --- | --- | --- |
| [ChatGPT 新聊天默认选择“聊天”](./ChatGPT%20%E6%96%B0%E8%81%8A%E5%A4%A9%E9%BB%98%E8%AE%A4%E9%80%89%E6%8B%A9%E2%80%9C%E8%81%8A%E5%A4%A9%E2%80%9D.user.js) | 新建普通对话时默认选择“聊天”，之后不干涉手动切换到“工作”。 | [直接安装](https://raw.githubusercontent.com/RongNianXin/codex-workflows/main/ChatGPT-Web/ChatGPT%20%E6%96%B0%E8%81%8A%E5%A4%A9%E9%BB%98%E8%AE%A4%E9%80%89%E6%8B%A9%E2%80%9C%E8%81%8A%E5%A4%A9%E2%80%9D.user.js) |
| [ChatGPT 左侧栏自由拖动宽度 V2](./ChatGPT%20%E5%B7%A6%E4%BE%A7%E6%A0%8F%E8%87%AA%E7%94%B1%E6%8B%96%E5%8A%A8%E5%AE%BD%E5%BA%A6%20V2.user.js) | 拖动左侧栏右边缘调整宽度，松开后自动保存；双击拖动线恢复默认宽度。 | [直接安装](https://raw.githubusercontent.com/RongNianXin/codex-workflows/main/ChatGPT-Web/ChatGPT%20%E5%B7%A6%E4%BE%A7%E6%A0%8F%E8%87%AA%E7%94%B1%E6%8B%96%E5%8A%A8%E5%AE%BD%E5%BA%A6%20V2.user.js) |

## 安装

### 从远端仓库安装（推荐）

1. 安装并启用篡改猴。
2. 点击上表中的“直接安装”。
3. 在篡改猴确认页检查脚本名称、匹配网站和权限，然后点击“安装”。
4. 刷新 ChatGPT 网页。

如果“直接安装”没有唤起篡改猴，请打开脚本的“查看源码”页面，再点击 `Raw`（原始文件）。

### 从本地文件安装

1. 下载以 `.user.js` 结尾的脚本文件。
2. 打开 `chrome://extensions`，进入篡改猴的“详细信息”，开启“允许访问文件网址”。
3. 把 `.user.js` 文件拖到 Chrome 页面中。
4. 在篡改猴确认页完成安装，然后刷新 ChatGPT 网页。

## 使用说明

### 新聊天默认选择“聊天”

脚本只在 ChatGPT 的普通新聊天页面尝试选择一次“聊天”。进入已有对话后，或者用户手动切换到“工作”后，脚本不会持续强制切换。

### 左侧栏自由拖动宽度

把鼠标移到左侧栏右边缘，按住出现的细线左右拖动。宽度限制为 200～650 像素；松开鼠标后保存设置，双击细线可恢复 ChatGPT 当前默认宽度。

## 权限与数据

- 两份脚本只匹配 `https://chatgpt.com/*`；侧栏脚本还兼容 `https://www.chatgpt.com/*`。
- 两份脚本都使用 `@grant none`，不申请篡改猴特权 API。
- 脚本不向外部服务器发起请求，也不读取 Cookie 或账号凭据。
- 侧栏脚本只在 ChatGPT 域名的浏览器本地存储中保存一个宽度数值。

## 常见问题

- 脚本没有运行：先检查脚本已启用，并确认 Chrome 的“允许运行用户脚本”开关已经开启。
- 点击安装链接只显示源码：进入篡改猴管理面板，新建脚本，粘贴完整源码并保存。
- 功能突然失效：ChatGPT 网页结构可能已经更新，请先停用脚本并查看仓库中的后续版本。

## 维护者：再次导入篡改猴备份

篡改猴的 ZIP 导出可能包含全部已安装脚本，以及脚本选项和存储数据。维护本目录时只处理 `.user.js`，不要提交备份 ZIP、`.options.json` 或 `.storage.json`。

重复导入时不依赖操作者或 AI 的历史记忆：

1. 使用 `@namespace + @name` 识别同一脚本。
2. 与仓库中现有 `.user.js` 比较内容；未变化的脚本跳过。
3. 同一脚本有变化时更新原文件，并递增 `@version`。
4. 只为新的脚本创建文件和 README 条目。
5. 备份中没有某个旧脚本，不等于要从仓库删除；删除需要单独确认。

因此，下一次备份同时包含脚本 1、2、3 时，脚本 1、2 会被比较而不是重复添加，只有脚本 3 会作为新增内容处理。

## 安全提示

- 安装前先阅读脚本源码，并检查其申请的网站范围和权限。
- ChatGPT 网页结构更新后，脚本可能需要同步调整。
- 本项目与 OpenAI、Google 或 Tampermonkey 官方不存在隶属或背书关系。

## 许可

脚本随本仓库按 [MIT License](../LICENSE) 发布。

## 参考资料

- [Tampermonkey：如何安装新脚本](https://www.tampermonkey.net/faq.php?q=Q102)
- [Tampermonkey：如何导入和导出脚本](https://www.tampermonkey.net/faq.php?locale=en&q=Q106)
- [Chrome：启用用户脚本 API](https://developer.chrome.com/docs/extensions/reference/api/userScripts?hl=zh-cn)
