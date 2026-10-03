// A way to carry a packet (JSON text) to the other device. The outbox files are always written;
// a transport is an additional, direct path (Wear Engine on real paired devices).

export interface DayTransport {
  name(): string;
  isAvailable(): Promise<boolean>;
  // Resolves with a short status text; rejects when the packet could not be handed over.
  send(json: string): Promise<string>;
}
