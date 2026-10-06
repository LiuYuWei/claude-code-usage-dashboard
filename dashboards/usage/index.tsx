import {
  BarChart,
  CalendarHeatmap,
  Dashboard,
  type DashboardMeta,
  Filters,
  Gauge,
  Heatmap,
  PieChart,
  Row,
  ScatterChart,
  Select,
  Stat,
  Table,
  TimeRange,
  Treemap,
} from '@open-dashboard/core'

export const meta: DashboardMeta = {
  title: 'Claude Code 使用分析',
  locale: 'zh-TW',
}

const usd = { style: 'currency', currency: 'USD', maximumFractionDigits: 0 } as const
const minutes = { style: 'unit', unit: 'minute', maximumFractionDigits: 0 } as const

export default function Usage() {
  return (
    <Dashboard>
      <Filters>
        <TimeRange label="期間" default="90d" options={['7d', '30d', '90d', 'all']} />
        <Select name="project" label="專案" query="projects" allLabel="全部專案" />
      </Filters>

      <Row>
        <Stat title="工作階段" query="totals" column="sessions" format="integer" />
        <Stat title="使用者訊息" query="totals" column="prompts" format="integer" />
        <Stat title="API 請求" query="totals" column="requests" format="compact" />
        <Stat title="輸出 Token" query="totals" column="output_tokens" format="compact" />
        <Stat title="費用" query="totals" column="cost" format={usd} />
        <Stat title="新增程式碼行數" query="totals" column="lines_added" format="compact" />
      </Row>

      <Row height={300}>
        <CalendarHeatmap title="每日 API 請求" query="daily" x="day" value="requests" format="integer" span={4} />
        <Heatmap title="一週工作節奏（時段 × 星期）" query="rhythm" x="hour" y="weekday" value="requests" format="integer" span={8} />
      </Row>

      <Row height={340}>
        <BarChart
          title="每日輸出 Token（依模型）"
          query="output_by_model"
          x="day"
          y="tokens"
          series="model"
          stacked
          format="compact"
          span={5}
        />
        <Treemap title="各專案費用" query="project_cost" label="project" value="cost" format={usd} span={4} />
        <Gauge title="提示快取命中率" query="cache_rate" column="rate" format="percent" span={3} />
      </Row>

      <Row height={360}>
        <BarChart title="最常使用的工具" query="tools" x="tool" y="calls" horizontal format="integer" span={4} />
        <BarChart
          title="工具失敗率（呼叫 20 次以上）"
          query="tool_errors"
          x="tool"
          y="error_rate"
          horizontal
          format="percent"
          span={4}
        />
        <ScatterChart
          title="API 運算時間（橫軸）與費用（縱軸）"
          query="session_scatter"
          x="minutes"
          y="cost"
          size="lines_added"
          label="project"
          format={usd}
          xFormat={minutes}
          span={4}
        />
      </Row>

      <Row height={380}>
        <Table
          title="最近的工作階段"
          query="recent_sessions"
          columns={[
            { key: 'started', label: '開始' },
            { key: 'project', label: '專案' },
            { key: 'prompts', label: '訊息', format: 'integer', align: 'right' },
            { key: 'requests', label: '請求', format: 'integer', align: 'right' },
            { key: 'cost', label: '費用', format: usd, align: 'right', bar: true },
            { key: 'lines_added', label: '新增', format: 'integer', align: 'right' },
            { key: 'lines_removed', label: '刪除', format: 'integer', align: 'right' },
          ]}
          span={8}
        />
        <PieChart title="模型使用比例" query="model_share" label="model" value="requests" format="integer" span={4} />
      </Row>
    </Dashboard>
  )
}
