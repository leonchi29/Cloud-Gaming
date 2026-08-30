export interface AgentConfig {
  backendUrl: string;
  agentToken: string;
  sunshinePath: string;
  sunshineCheckIntervalMs: number;
  streamFps: number;
}

export function loadConfig(): AgentConfig {
  return {
    backendUrl: process.env.BACKEND_URL ?? 'http://localhost:4000',
    agentToken: process.env.AGENT_TOKEN ?? 'cambia-este-token-seguro',
    sunshinePath: process.env.SUNSHINE_PATH ?? 'C:\\Program Files\\Sunshine\\sunshine.exe',
    sunshineCheckIntervalMs: Number(process.env.SUNSHINE_CHECK_INTERVAL_MS) || 15000,
    streamFps: Math.min(Math.max(Number(process.env.STREAM_FPS) || 8, 1), 30),
  };
}
