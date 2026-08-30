export type InputEventType =
  | 'mousemove'
  | 'mousedown'
  | 'mouseup'
  | 'wheel'
  | 'keydown'
  | 'keyup';

export interface MouseInputEvent {
  type: 'mousemove' | 'mousedown' | 'mouseup';
  /** Coordenadas normalizadas 0..1 respecto al área de vídeo mostrada */
  x: number;
  y: number;
  button: 'left' | 'middle' | 'right';
}

export interface WheelInputEvent {
  type: 'wheel';
  deltaX: number;
  deltaY: number;
}

export interface KeyboardInputEvent {
  type: 'keydown' | 'keyup';
  /** DOM KeyboardEvent.key */
  key: string;
  /** DOM KeyboardEvent.code */
  code: string;
}

export type InputEvent = MouseInputEvent | WheelInputEvent | KeyboardInputEvent;

export interface StreamFrame {
  /** Imagen codificada en base64 (data URI sin prefijo o con prefijo) */
  data: string;
  format: 'jpeg' | 'png';
  width: number;
  height: number;
  timestamp: number;
}

export interface HostStatus {
  online: boolean;
  sunshineRunning: boolean;
  sessionActive: boolean;
}

export interface SignalPayload {
  /** SDP offer/answer o ICE candidate serializados */
  kind: 'offer' | 'answer' | 'ice';
  data: unknown;
}
