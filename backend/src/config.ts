export interface BackendConfig {
  port: number;
  corsOrigin: string;
  agentToken: string;
}

export function loadConfig(): BackendConfig {
  return {
    port: Number(process.env.PORT) || 4000,
    corsOrigin: process.env.CORS_ORIGIN ?? '*',
    agentToken: process.env.AGENT_TOKEN ?? 'cambia-este-token-seguro',
  };
}
