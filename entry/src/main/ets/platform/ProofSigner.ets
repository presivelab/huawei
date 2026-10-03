// Moved to the common HAR so the watch can sign day packets with its own key (another alias).
// The phone's claim key, alias and behaviour are unchanged: ProofSigner.shared().
export { DeviceKey, KeySource, ProofSigner } from 'common';
