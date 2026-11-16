import {NativeEventEmitter, NativeModules, requireNativeComponent} from 'react-native';
import type {NativeSyntheticEvent, ViewProps} from 'react-native';
import type {Attachment, ID} from './state/model';

export type Rect = {x: number; y: number; width: number; height: number};
export type WindowLayout = {margins: {left: number; right: number}; regions: Rect[]};
export type Configuration = {media: string; fileBase: string; supportEmail: string; purchasesEnabled: boolean};
export type Policy = 'terms' | 'privacy' | 'rules';
export type PickSource = 'photos' | 'picture' | 'movie';
export type Identity = {key: string; id: ID; name?: string};
export type FilmState = {
  id?: ID;
  engaged: boolean;
  playing: boolean;
  muted: boolean;
  time: number;
  duration: number;
  loading: boolean;
  failed: boolean;
};
export type VerifiedPurchase = {id: ID; owner: ID; productID: ID; revoked: boolean};
export type Offer = {id: ID; name: string; price: string};
export type PurchaseResult =
  | {status: 'purchased'; transaction: VerifiedPurchase}
  | {status: 'pending' | 'cancelled' | 'unverified' | 'unknown'};

type Bootstrap = {
  json: string | null;
  legacy: boolean;
  legacyNeedsCleanup: boolean;
  activeID: ID | null;
  config: Configuration;
  layout: WindowLayout;
};
type PlatformMethods = {
  bootstrap: [undefined, Bootstrap];
  writeArchive: [{json: string; removeLegacy?: boolean}, void];
  cleanLegacy: [undefined, void];
  session: [{id: ID | null}, void];
  identity: [{value: string}, Identity];
  appleSignIn: [undefined, Identity];
  pick: [{owner: ID; source: PickSource; avatar: boolean}, Attachment | null];
  removeAttachment: [{owner: ID; attachment: Attachment}, void];
  removeAccount: [{owner: ID}, void];
  playFilm: [{id: ID; uri: string}, void];
  pauseFilm: [undefined, void];
  releaseFilm: [undefined, void];
  muteFilm: [undefined, void];
  seekFilm: [{seconds: number}, void];
  beginCall: [{video: boolean; requestID: ID}, void];
  stopCall: [{requestID: ID}, void];
  quote: [{productID: ID}, Offer];
  purchase: [{productID: ID; owner: ID}, PurchaseResult];
  recoverPurchases: [undefined, VerifiedPurchase[]];
  startPurchases: [undefined, VerifiedPurchase[]];
  finishPurchase: [{transactionID: ID}, void];
};

const device = NativeModules.NinaDevice;

export function platform<K extends keyof PlatformMethods>(
  operation: K,
  ...args: PlatformMethods[K][0] extends undefined ? [] : [PlatformMethods[K][0]]
): Promise<PlatformMethods[K][1]> {
  return device.perform(operation, args[0] ?? {});
}

const events = new NativeEventEmitter(device);
export const onLayoutChange = (event: (layout: WindowLayout) => void) => events.addListener('NinaWindowLayout', event);
export const onFilmChange = (event: (state: FilmState) => void) => events.addListener('NinaFilmState', event);
export const onPurchase = (event: (transaction: VerifiedPurchase) => void) => events.addListener('NinaPurchase', event);
export const onAppleRevocation = (event: () => void) => events.addListener('NinaAppleRevoked', event);
export const onCallStopped = (event: () => void) => events.addListener('NinaCallStopped', event);

export type SurfaceSignal =
  | {status: 'pressed'}
  | {status: 'loading' | 'loaded' | 'failed'};
type SurfaceProps = ViewProps & {
  kind: 'apple' | 'film' | 'camera' | 'policy';
  enabled?: boolean;
  policy?: Policy;
  revision?: number;
  onSignal?: (event: NativeSyntheticEvent<SurfaceSignal>) => void;
};
export const NativeSurface = requireNativeComponent<SurfaceProps>('NinaSurface');

export function mediaURI(config: Configuration, path?: string | null) {
  if (!config.media || !path || !path.split('/').every(part => /^[a-z0-9][a-z0-9.-]*$/.test(part))) {
    return undefined;
  }
  return `${config.media.replace(/\/$/, '')}/${path}`;
}

export function attachmentURI(config: Configuration, owner: ID, file?: string) {
  if (!file || !/^[\da-f-]{36}$/i.test(owner) || !/^[\da-f-]{36}\.[a-z0-9]{1,8}$/i.test(file)) {
    return undefined;
  }
  return `${config.fileBase.replace(/\/$/, '')}/${owner}/${file}`;
}
