# Claude Code 使用分析 Dashboard

[English](README.md) · **繁體中文**

在你自己的電腦上，看清楚你怎麼使用 Claude Code：token、費用、模型、工具、專案，以及你都在什麼時間工作。它讀取的是 Claude Code 本來就存在你電腦裡的對話紀錄。**不會上傳到任何地方**，你跟 Claude 說過的內容也不會被複製——只留下數字和名稱。

以 [open-dashboard](https://github.com/simonliu-ai-product/open-dashboard) 打造。

## 看得到什麼

| 面板 | 回答的問題 |
| --- | --- |
| 工作階段、使用者訊息、API 請求、輸出 Token、費用、新增程式碼行數 | 所選期間與專案的總量 |
| 每日 API 請求（月曆） | 哪幾天用了 Claude Code、用了多少 |
| 一週工作節奏（時段 × 星期） | 一週裡你都在什麼時間用它 |
| 每日輸出 Token（依模型） | 輸出量在各模型間怎麼分配、什麼時候換了模型 |
| 各專案費用 | 錢花在哪些專案 |
| 提示快取命中率 | 輸入有多少是從提示快取讀取 |
| 最常使用的工具・工具失敗率 | Claude 都在幫你做什麼、哪些最常失敗 |
| API 運算時間與費用 | 每個工作階段等待 API 的時間、費用與新增的程式碼行數 |
| 最近的工作階段・模型使用比例 | 最新的工作階段，以及各模型的使用比例 |

所有面板都能依期間與專案篩選。

第二張 Dashboard「**Claude Code 深入分析**」看得更深：

| 面板 | 回答的問題 |
| --- | --- |
| 工具接續流程（Sankey） | Claude 讀完檔、改完檔、跑完指令、用完瀏覽器之後，下一步通常做什麼 |
| 工作階段的費用集中度（Pareto） | 最花錢的 20% 工作階段佔了多少費用 |
| 專案每週請求排名・前六大專案的每週請求 | 每一週的主力專案是哪個 |
| 各模型單次回應的輸出 Token（箱形圖） | 各模型的回答有多長 |
| 工作階段費用的累積分布（ECDF） | 「一半的工作階段花費在多少以內、九成在多少以內」 |
| 每日請求的異常偵測（管制圖） | 哪幾天用量遠高於平常 |
| 各專案的工具類型組成（Marimekko） | 一個專案主要是在跑指令、改檔、讀檔還是用瀏覽器 |
| 各專案程式碼淨增減・每則訊息帶動的 API 請求數 | 哪些專案在長大，以及每則訊息 Claude 會自主做多少事 |
| 新專案之後幾週的回訪（Cohort） | 開始一個專案後，接下來幾週還會回來用多少 |

## 為什麼我的額度一下就用完了？

第三張 Dashboard「**Claude Code 用量診斷**」就是為這個問題做的。一次請求用掉的 token，大部分通常不是 Claude 寫出的回答，而是回答前要**重新讀一遍**的整段對話——長的工作階段裡，往往超過 99%。原因與對應的面板：

| 在 Dashboard 上看到 | 代表什麼 | 可以怎麼做 |
| --- | --- | --- |
| **Token 花在讀入前文的比例**接近 100%、**每次請求讀入的 context** 達數十萬 | 每則訊息都要把到目前為止的整段對話重讀一次 | 換新任務就開新對話（`/clear`），太長的對話用 `/compact` 壓縮 |
| **context 增長**呈鋸齒狀，一路爬到模型上限 | 對話從來沒有清空，只在自動壓縮時變短，接著又繼續累積 | 同上：任務之間就清空，不要一個工作階段用一整天 |
| **工具回傳塞進 context 的字元數**集中在某個工具 | 很長的指令輸出、大檔案或大量截圖會留在 context 裡，之後每次請求都要重讀 | 請它縮短輸出（例如 `… \| tail -50`）、只讀大檔案的一部分、少截圖 |
| **快取重建次數** | 停頓太久後提示快取過期，整段 context 要重新寫入快取 | 在很長的工作階段中途長時間停頓會更耗用；休息回來就開新對話 |
| **子 Agent 請求比例** | 每個子 Agent 各自帶著 context 平行工作 | 只在真的需要時使用子 Agent |
| **各模型處理的 Token** | 越大的模型，同樣的工作會用掉越多方案額度 | 例行工作改用較小的模型 |
| **每 5 小時用量區間的 Token** | 方案用量以時間區間計算，這裡看得出哪些區間特別重 | 分散密集的工作，或在忙的區間把 context 維持精簡 |

5 小時區間是從紀錄推算的（前一個區間結束後的第一次請求開啟新區間），是近似值，不是方案本身的用量計量。

## 你的資料只留在你的電腦

**讀取什麼：** Claude Code 寫在 `~/.claude/projects/**/*.jsonl` 的對話紀錄（設定了 `CLAUDE_CONFIG_DIR` 時則是 `$CLAUDE_CONFIG_DIR/projects`）。

**保留什麼**——存在這個資料夾裡的 `data/usage.db`（SQLite 檔）：

- 每次請求與工具呼叫的時間，以及所屬專案（git repo 的資料夾名稱）
- 模型，以及 token 數（輸入、輸出、快取讀取與寫入）
- 呼叫的工具名稱、是否失敗，以及回傳內容有多大（字元數與圖片數——不含內容本身）
- 每個工作階段由 Claude Code 自己記錄的費用與新增／刪除行數
- 你輸入了幾則訊息——但不是訊息內容

**絕不保留：** 你的提問、Claude 的回答與思考過程、工作階段標題、檔案路徑、檔案內容、指令，以及工具的輸入與輸出。

- `data/` 已列在 `.gitignore`：你的使用資料永遠不會被 commit，可以放心 fork、push 這個專案。
- Dashboard 只在 `localhost` 執行，以唯讀方式讀取 `data/usage.db`，不會對外傳送任何資料。
- 想刪除收集到的所有資料，刪掉 `data/usage.db` 即可。

## 開始使用

需要：

- [Node.js](https://nodejs.org) 22.18 以上與 [pnpm](https://pnpm.io)
- [uv](https://docs.astral.sh/uv/)，收集程式會用到（它會自行安裝所需的 Python）
- 這台電腦上至少用過一次 Claude Code

（有 [mise](https://mise.jdx.dev) 的話，`mise install` 會依 `.mise.toml` 裝好 Node、pnpm 與 Python。）

```bash
git clone https://github.com/LiuYuWei/claude-code-usage-dashboard.git
cd claude-code-usage-dashboard
pnpm install
pnpm dev
```

`pnpm dev` 會先收集你的使用資料（就算紀錄有幾百 MB，也只要幾秒），再開啟 Dashboard：**http://localhost:5473**。

## 更新數字

收集程式只會讀取上次之後有變動的紀錄。Dashboard 開著的時候，要更新數字就執行：

```bash
pnpm collect
```

再重新整理頁面即可；重新啟動 `pnpm dev` 也一樣。

如果 Claude Code 的資料放在其他位置，告訴收集程式：

```bash
CLAUDE_CONFIG_DIR=/path/to/claude-config pnpm collect
```

## 需要知道的事

- **費用是 Claude Code 自己記錄的數字**，在工作階段結束時寫入。還開著的工作階段在那之前會顯示 `—`，所以總費用是已結束工作階段的合計。
- **專案以 git repo 命名**——在 `my-app/packages/web` 裡的工作階段算在 `my-app`。不在 repo 裡的，就用資料夾本身的名稱。
- **時間是你電腦的當地時間。**
- **工作階段可能橫跨好幾天**（你中途接著用），所以「花了多久」用的是等待 API 的時間，而不是第一則到最後一則訊息的間隔。
- 對話紀錄的格式是 Claude Code 內部的，版本更新後可能改變。如果更新後某個面板變成空的，歡迎開 issue。

## 分享一張截圖

右上角「預覽／編輯」旁的下載按鈕，可以把整張 Dashboard 存成 PNG 或 SVG——只有圖表和統計結果，沒有背後的資料。分享前請先看一下內容：**圖上會出現專案名稱**，可能是客戶或產品名稱。

## 改成你想要的樣子

這是一個 [open-dashboard](https://github.com/simonliu-ai-product/open-dashboard) workspace：面板寫在 `dashboards/usage/index.tsx`（React），查詢寫在 `dashboards/usage/queries.sql`（SQL），每張資料表的意思寫在 `databases/usage/database.md`。專案內建了給 Coding Agent 用的 skills——用 Claude Code 打開這個資料夾，直接說你想要的面板（例如「加一張每週各模型的費用」）。

```
collector/collect.py          讀取 ~/.claude/projects，寫入 data/usage.db
dashboards/usage/             總覽：index.tsx（版面）與 queries.sql
dashboards/insights/          深入分析，結構相同
dashboards/diagnosis/         用量診斷，結構相同
databases/usage/database.md   每張資料表與欄位的說明
open-dashboard.config.ts      資料來源：data/usage.db
```

```bash
pnpm collect                              # 更新 data/usage.db
pnpm exec open-dashboard check            # 執行所有查詢，檢查每個面板
pnpm exec open-dashboard query "SELECT model, COUNT(*) FROM requests GROUP BY model"
```

## 授權

MIT
