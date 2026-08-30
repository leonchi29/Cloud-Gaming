import { io, Socket } from 'socket.io-client';

const BACKEND_URL: string =
  (import.meta.env.VITE_BACKEND_URL as string | undefined) ??
  'http://localhost:4000';

let socket: Socket | null = null;

/** Devuelve la instancia singleton del socket (con reconexión automática). */
export function getSocket(): Socket {
  if (!socket) {
    socket = io(BACKEND_URL, {
      transports: ['websocket'],
      reconnection: true,
      reconnectionAttempts: Infinity,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 10000,
      timeout: 20000,
    });
  }
  return socket;
}

export function getBackendUrl(): string {
  return BACKEND_URL;
}
