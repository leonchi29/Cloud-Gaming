import robot from 'robotjs';
import { logger } from './logger';
import type { InputEvent, KeyboardInputEvent, MouseInputEvent, WheelInputEvent } from './types';

/** Mapa de teclas DOM KeyboardEvent.key → nombres de robotjs */
const SPECIAL_KEYS: Record<string, string> = {
  Enter: 'enter',
  Escape: 'escape',
  Backspace: 'backspace',
  Tab: 'tab',
  ' ': 'space',
  Shift: 'shift',
  Control: 'control',
  Alt: 'alt',
  Meta: 'command',
  ArrowUp: 'up',
  ArrowDown: 'down',
  ArrowLeft: 'left',
  ArrowRight: 'right',
  Home: 'home',
  End: 'end',
  PageUp: 'pageup',
  PageDown: 'pagedown',
  Delete: 'delete',
  Insert: 'insert',
  CapsLock: 'capslock',
  PrintScreen: 'printscreen',
  ScrollLock: 'scrolllock',
  Pause: 'pause',
  NumLock: 'numlock',
  F1: 'f1', F2: 'f2', F3: 'f3', F4: 'f4', F5: 'f5', F6: 'f6',
  F7: 'f7', F8: 'f8', F9: 'f9', F10: 'f10', F11: 'f11', F12: 'f12',
};

function resolveKey(key: string): string | null {
  if (key.length === 1) {
    return key.toLowerCase();
  }
  return SPECIAL_KEYS[key] ?? null;
}

function screenPoint(xNorm: number, yNorm: number): { x: number; y: number } {
  const size = robot.getScreenSize();
  return {
    x: Math.round(Math.min(Math.max(xNorm, 0), 1) * (size.width - 1)),
    y: Math.round(Math.min(Math.max(yNorm, 0), 1) * (size.height - 1)),
  };
}

function handleMouse(event: MouseInputEvent): void {
  const { x, y } = screenPoint(event.x, event.y);
  robot.moveMouse(x, y);
  if (event.type === 'mousedown') {
    robot.mouseToggle('down', event.button);
  } else if (event.type === 'mouseup') {
    robot.mouseToggle('up', event.button);
  }
}

function handleWheel(event: WheelInputEvent): void {
  // robotjs scrollMouse usa "clicks" enteros; normalizamos los deltas del navegador
  const clicksY = Math.round(-event.deltaY / 120);
  const clicksX = Math.round(event.deltaX / 120);
  if (clicksY !== 0) robot.scrollMouse(0, clicksY);
  if (clicksX !== 0) robot.scrollMouse(clicksX, 0);
}

function handleKeyboard(event: KeyboardInputEvent): void {
  const key = resolveKey(event.key);
  if (!key) {
    logger.warn('Tecla no mapeada', { key: event.key, code: event.code });
    return;
  }
  try {
    robot.keyToggle(key, event.type === 'keydown' ? 'down' : 'up');
  } catch (err) {
    logger.warn('Error enviando tecla', { key, err: String(err) });
  }
}

/** Aplica un evento de entrada recibido desde el navegador. */
export function applyInputEvent(event: InputEvent): void {
  try {
    switch (event.type) {
      case 'mousemove':
      case 'mousedown':
      case 'mouseup':
        handleMouse(event);
        break;
      case 'wheel':
        handleWheel(event);
        break;
      case 'keydown':
      case 'keyup':
        handleKeyboard(event);
        break;
      default:
        logger.warn('Evento de entrada desconocido', event);
    }
  } catch (err) {
    logger.error('Error aplicando evento de entrada', { err: String(err) });
  }
}

/** Libera todas las teclas/botones al cerrar sesión para evitar estados atascados. */
export function releaseAllInputs(): void {
  const keysToRelease = ['shift', 'control', 'alt', 'command'];
  for (const key of keysToRelease) {
    try {
      robot.keyToggle(key, 'up');
    } catch {
      /* ignorar */
    }
  }
  for (const button of ['left', 'middle', 'right'] as const) {
    try {
      robot.mouseToggle('up', button);
    } catch {
      /* ignorar */
    }
  }
}
