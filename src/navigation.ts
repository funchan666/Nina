import {createContext, useContext} from 'react';
import type {WebPage} from './native';
import type {ID, Subject} from './state/model';

export type Tab = 'lines' | 'sessions' | 'crew' | 'messages' | 'profile';
export type Route =
  | {name: 'collection' | 'savedLines'}
  | {name: 'line' | 'lineViewer'; id: ID}
  | {name: 'post'; id?: ID}
  | {name: 'submissions'}
  | {name: 'submissionViewer'; id: ID}
  | {name: 'spotEditor'; id?: ID; reference?: ID}
  | {name: 'spot'; id: ID}
  | {name: 'trick'; id?: ID; spot?: ID; reference?: ID}
  | {name: 'crewAtSpot'; spotKey: string; title: string}
  | {name: 'profile'; id: ID}
  | {name: 'profileEditor'}
  | {name: 'relationships'; id: ID; incoming: boolean}
  | {name: 'messages'}
  | {name: 'conversation'; id: ID}
  | {name: 'call'; id: ID; video: boolean}
  | {name: 'report'; subject: Subject}
  | {name: 'block'; id: ID}
  | {name: 'webPage'; page: WebPage}
  | {name: 'blacklist' | 'settings' | 'deleteProfile' | 'wallet' | 'covers'};

type Flow = {
  visible: boolean;
  open(route: Route): void;
  back(): void;
  select(tab: Tab): void;
  notice(text: string): void;
};

export const FlowContext = createContext<Flow | null>(null);

export function useFlow() {
  const flow = useContext(FlowContext);
  if (!flow) {
    throw new Error('The screen needs a Nina navigation context.');
  }
  return flow;
}

export function errorText(error: unknown) {
  return error instanceof Error ? error.message : 'That change could not be saved. Try again.';
}
