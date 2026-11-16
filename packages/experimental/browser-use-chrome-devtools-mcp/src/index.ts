/** Chromium inspection and automation through the pinned Chrome DevTools MCP server. @module */

import { fileURLToPath } from 'node:url'
import type { Context } from '@deepseek-ai/cordis'
import Schema from '@deepseek-ai/schemastery'
import { BrowserMcpConfig, mountSessionMcp, validateBrowserMcpConfig } from '@deepseek-ai/dsh-experimental-browser-use-runtime/mcp'
import type { BrowserMcpAttachConfig, BrowserMcpLaunchConfig } from '@deepseek-ai/dsh-experimental-browser-use-runtime/mcp'
import type {} from '@deepseek-ai/dsh-working-directory'

/** Cordis identity for the Chrome DevTools MCP browser provider. */
export const name = 'experimental-browser-use-chrome-devtools-mcp'

/** Services required for scoped MCP startup and prompt readiness checks. */
export const inject = ['browserUse', 'agents', 'tools', 'systemPrompt', 'workingDirectory']

/** Chrome channels supported by the upstream auto-connect handshake. */
type ChromeChannel = 'stable' | 'beta' | 'dev' | 'canary'

/** Connect to a running Chrome instance through its permission-based debugging handshake. */
interface AutoConnectConfig {
  /** Connect through Chrome's remote-debugging permission dialog. */
  mode: 'autoConnect'
  /** Chrome installation channel to locate for the auto-connect handshake. */
  channel: ChromeChannel
  /** Per-call timeout in milliseconds; omission uses the MCP client default. */
  toolCallTimeoutMs?: number
}

/** Launch settings accepted before the shared schema supplies its default headless value. */
type LaunchConfigInput = Omit<BrowserMcpLaunchConfig, 'headless'> & { headless?: boolean }

/** Chromium launch, endpoint attachment, or permission-based Chrome auto-connect settings. */
export type Config = LaunchConfigInput | BrowserMcpAttachConfig | AutoConnectConfig

/** Browser settings after schema defaults have been applied. */
type ResolvedConfig = BrowserMcpConfig | AutoConnectConfig

/** Validate launch, endpoint attachment, or Chrome's permission-based auto-connect configuration. */
export const Config: Schema<Config, ResolvedConfig> = Schema.union([
  BrowserMcpConfig,
  Schema.object({
    mode: Schema.const('autoConnect').required(),
    channel: Schema.union(['stable', 'beta', 'dev', 'canary']).required(),
    toolCallTimeoutMs: Schema.number().min(1),
  }),
])

/**
 * Expose Chrome DevTools' upstream catalog through one MCP process per live Session.
 * Attached browsers remain externally owned; the server disables usage statistics.
 * @param ctx - provider context supplying browser use, Agents, and tools.
 * @param config - validated browser choice and optional tool timeout.
 */
export function apply(ctx: Context, config: ResolvedConfig): void {
  if (config.mode === 'attach') validateBrowserMcpConfig(config)
  const cli = fileURLToPath(import.meta.resolve('chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js'))
  const args = [cli, '--no-usage-statistics']
  if (config.mode === 'autoConnect') {
    args.push('--autoConnect', '--channel', config.channel)
  } else if (config.mode === 'attach') {
    args.push(/^wss?:/u.test(config.endpoint) ? '--ws-endpoint' : '--browser-url', config.endpoint)
  } else {
    args.push('--isolated', `--headless=${String(config.headless)}`)
    if (config.executablePath !== undefined) args.push('--executable-path', config.executablePath)
  }
  mountSessionMcp(ctx, {
    name: 'chrome-devtools-mcp',
    exclusive: config.mode !== 'launch',
    command: process.execPath,
    args,
    ...config.toolCallTimeoutMs === undefined ? {} : { toolCallTimeoutMs: config.toolCallTimeoutMs },
  })
}
