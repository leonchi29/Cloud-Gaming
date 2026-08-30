import express, { Request, Response } from 'express';
import http from 'http';
import cors from 'cors';
import { Server } from 'socket.io';
import { loadConfig } from './config';
import { logger } from './logger';
import { SessionManager } from './sessionManager';
import { registerSocketHandlers } from './socketHandlers';
import type { HostStatus } from './types';

const config = loadConfig();
const sessions = new SessionManager();

const app = express();
app.use(cors({ origin: config.corsOrigin === '*' ? true : config.corsOrigin }));
app.use(express.json());

app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.get('/status', (_req: Request, res: Response) => {
  const status: HostStatus = {
    online: sessions.isHostOnline(),
    sunshineRunning: sessions.isSunshineRunning(),
    sessionActive: sessions.hasActiveSession(),
  };
  res.json(status);
});

const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: config.corsOrigin === '*' ? true : config.corsOrigin,
    methods: ['GET', 'POST'],
  },
  // Frames de vídeo en base64 pueden superar el límite por defecto (1 MB)
  maxHttpBufferSize: 15 * 1024 * 1024,
  pingInterval: 10000,
  pingTimeout: 20000,
});

registerSocketHandlers(io, sessions, config.agentToken);

server.listen(config.port, () => {
  logger.info(`Backend escuchando en el puerto ${config.port}`);
});

function shutdown(signal: string): void {
  logger.info(`Señal ${signal} recibida, apagando...`);
  io.close();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 5000).unref();
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('unhandledRejection', (reason) => {
  logger.error('unhandledRejection', reason);
});
