import type { OpenDashboardConfig } from '@open-dashboard/core'

export default {
  datasources: {
    // Numbers only, collected from ~/.claude/projects by collector/collect.py (`pnpm collect`).
    usage: { type: 'sqlite', file: 'data/usage.db' },
  },
  defaultSource: 'usage',
} satisfies OpenDashboardConfig
