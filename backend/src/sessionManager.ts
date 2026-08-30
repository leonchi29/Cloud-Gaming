import { logger } from './logger';

/**
 * Gestiona la única sesión remota activa permitida.
 */
export class SessionManager {
  private agentSocketId: string | null = null;
  private activeClientId: string | null = null;
  private sunshineRunning = false;

  registerAgent(socketId: string): void {
    this.agentSocketId = socketId;
    logger.info('Agente registrado', { socketId });
  }

  unregisterAgent(socketId: string): void {
    if (this.agentSocketId === socketId) {
      this.agentSocketId = null;
      this.sunshineRunning = false;
      logger.info('Agente desconectado', { socketId });
    }
  }

  isHostOnline(): boolean {
    return this.agentSocketId !== null;
  }

  getAgentSocketId(): string | null {
    return this.agentSocketId;
  }

  setSunshineRunning(running: boolean): void {
    this.sunshineRunning = running;
  }

  isSunshineRunning(): boolean {
    return this.sunshineRunning;
  }

  /** Intenta abrir una sesión para un cliente. Devuelve true si se concedió. */
  openSession(clientId: string): boolean {
    if (!this.isHostOnline()) return false;
    if (this.activeClientId !== null && this.activeClientId !== clientId) return false;
    this.activeClientId = clientId;
    logger.info('Sesión concedida', { clientId });
    return true;
  }

  closeSession(clientId: string): boolean {
    if (this.activeClientId === clientId) {
      this.activeClientId = null;
      logger.info('Sesión cerrada', { clientId });
      return true;
    }
    return false;
  }

  getActiveClientId(): string | null {
    return this.activeClientId;
  }

  hasActiveSession(): boolean {
    return this.activeClientId !== null;
  }
}
