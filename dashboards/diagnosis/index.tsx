import {
  BarChart,
  Dashboard,
  type DashboardMeta,
  Filters,
  LineChart,
  PieChart,
  Row,
  Stat,
  Table,
  TimeRange,
} from '@open-dashboard/core'

export const meta: DashboardMeta = {
  title: 'Claude Code 用量診斷',
  locale: 'zh-TW',
}

const pct = { style: 'percent', maximumFractionDigits: 1 } as const

export default function Diagnosis() {
  return (
    <Dashboard>
      <Filters>
        <TimeRange label="期間" default="30d" options={['7d', '30d', '90d', 'all']} />
      </Filters>

      <Row>
        <Stat title="Token 花在讀入前文的比例" query="diagnosis_totals" column="read_share" format={pct} />
        <Stat title="平均每次請求讀入的 context" query="diagnosis_totals" column="avg_context" format="compact" />
        <Stat title="讀入超過 20 萬 Token 的請求" query="diagnosis_totals" column="over_200k" format={pct} />
        <Stat title="快取重建次數" query="diagnosis_totals" column="rebuilds" format="integer" />
        <Stat title="子 Agent 請求比例" query="diagnosis_totals" column="subagent_share" format={pct} />
        <Stat title="工具回傳的圖片" query="images" column="images" format="integer" />
      </Row>

      <Row height={340}>
        <BarChart
          title="每 5 小時用量區間的 Token"
          query="windows"
          x="window"
          y={['讀入 context', '輸出']}
          stacked
          format="compact"
          span={8}
        />
        <BarChart title="每次請求讀入的 context 大小" query="context_sizes" x="size" y="requests" format="integer" span={4} />
      </Row>

      <Row height={340}>
        <LineChart
          title="對話沒清空時 context 的增長（最耗用的五個工作階段）"
          query="context_growth"
          x="request"
          y="context"
          series="session"
          format="compact"
          span={6}
        />
        <BarChart title="工具回傳塞進 context 的字元數" query="tool_payload" x="tool" y="chars" horizontal format="compact" span={3} />
        <PieChart title="各模型處理的 Token" query="model_tokens" label="model" value="tokens" format="compact" span={3} />
      </Row>

      <Row height={420}>
        <Table
          title="最耗用的工作階段"
          query="heavy_sessions"
          columns={[
            { key: 'started', label: '開始' },
            { key: 'project', label: '專案' },
            { key: 'requests', label: '請求', format: 'integer', align: 'right' },
            { key: 'tokens', label: '處理 Token', format: 'compact', align: 'right', bar: true },
            { key: 'avg_context', label: '平均 context', format: 'compact', align: 'right' },
            { key: 'max_context', label: '最大 context', format: 'compact', align: 'right' },
            { key: 'rebuilds', label: '快取重建', format: 'integer', align: 'right' },
            { key: 'subagent_requests', label: '子 Agent 請求', format: 'integer', align: 'right' },
            { key: 'model', label: '主要模型' },
          ]}
        />
      </Row>
    </Dashboard>
  )
}
