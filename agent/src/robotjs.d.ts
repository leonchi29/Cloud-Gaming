/**
 * Declaración de tipos local para robotjs (no existe @types/robotjs en npm).
 * Cubre únicamente la API utilizada por el agente.
 */
declare module 'robotjs' {
  export interface ScreenSize {
    width: number;
    height: number;
  }

  export function getScreenSize(): ScreenSize;
  export function moveMouse(x: number, y: number): void;
  export function mouseToggle(
    down: 'down' | 'up',
    button?: 'left' | 'right' | 'middle',
  ): void;
  export function scrollMouse(x: number, y: number): void;
  export function keyToggle(
    key: string,
    down: 'down' | 'up',
    modifier?: string | string[],
  ): void;

  const robot: {
    getScreenSize: typeof getScreenSize;
    moveMouse: typeof moveMouse;
    mouseToggle: typeof mouseToggle;
    scrollMouse: typeof scrollMouse;
    keyToggle: typeof keyToggle;
  };

  export default robot;
}
