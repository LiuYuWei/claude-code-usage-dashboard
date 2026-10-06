import {
  BoxPlot,
  BumpChart,
  CohortTable,
  ControlChart,
  Dashboard,
  type DashboardMeta,
  DivergingBar,
  DotPlot,
  EcdfChart,
  Filters,
  Marimekko,
  ParetoChart,
  Row,
  Sankey,
  SmallMultiples,
  TimeRange,
} from '@open-dashboard/core'

export const meta: DashboardMeta = {
  title: 'Claude Code 深入分析',
  locale: 'zh-TW',
}

const usd = { style: 'currency', currency: 'USD', maximumFractionDigits: 0 } as const
const times = { maximumFractionDigits: 1 } as const

export default function Insights() {
  return (
    <Dashboard>
      <Filters>
        <TimeRange label="期間" default="90d" options={['30d', '90d', 'all']} />
      </Filters>

      <Row height={400}>
        <Sankey title="工具接續流程（這一步 → 下一步）" query="tool_flow" source="source" target="target" value="calls" format="integer" span={7} />
        <ParetoChart title="工作階段的費用集中度" query="cost_pareto" label="session" value="cost" format={usd} span={5} />
      </Row>

      <Row height={340}>
        <BumpChart title="專案每週請求排名" query="weekly_rank" x="week" series="project" value="requests" top={5} format="integer" span={6} />
        <SmallMultiples
          title="前六大專案的每週請求"
          query="weekly_top"
          x="week"
          y="requests"
          series="project"
          kind="bar"
          format="integer"
          span={6}
        />
      </Row>

      <Row height={320}>
        <BoxPlot
          title="各模型單次回應的輸出 Token"
          query="output_by_model"
          label="model"
          stats={{ min: 'p5', q1: 'p25', median: 'p50', q3: 'p75', max: 'p95' }}
          format="integer"
          span={4}
        />
        <EcdfChart title="工作階段費用的累積分布" query="session_costs" value="cost" marks={[0.5, 0.9]} format={usd} span={4} />
        <ControlChart title="每日請求的異常偵測" query="daily_requests" x="day" y="requests" format="integer" span={4} />
      </Row>

      <Row height={360}>
        <Marimekko title="各專案的工具類型組成" query="project_tools" x="project" series="kind" value="calls" format="integer" span={6} />
        <DivergingBar title="各專案程式碼淨增減（行）" query="net_lines" label="project" value="net" format="integer" span={3} />
        <DotPlot title="每則訊息帶動的 API 請求數" query="autonomy" label="project" value="per_message" format={times} span={3} />
      </Row>

      <Row height={300}>
        <CohortTable
          title="新專案之後幾週的回訪"
          query="project_return"
          cohort="cohort"
          period="week_number"
          value="projects"
          size="size"
          span={12}
        />
      </Row>
    </Dashboard>
  )
}
