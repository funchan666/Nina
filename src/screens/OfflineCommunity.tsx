import React, {useState} from 'react';
import {requireNativeComponent, StyleSheet, View} from 'react-native';
import type {NativeSyntheticEvent, ViewProps} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import {mediaFilename} from '../native';
import type {Policy, Rect} from '../native';
import {errorText} from '../navigation';
import type {Route, Tab} from '../navigation';
import {library, visibleSkater} from '../state/library';
import {collectionNames, findLine, isReported, lines} from '../state/model';
import type {Line} from '../state/model';
import {freeBand, useWindowBounds, useWindowLayout} from '../ui/geometry';
import {Action, colors, Copy, Glyph, layout} from '../ui/paper';
import {WebPageScreen} from '../ui/WebPage';

export type JournalDestination = {tab: Tab; route?: Route};
type Request = {status: 'request'; id: string; action: string; data: unknown};
type Signal = Request | {status: 'loaded' | 'failed'};
type Reply = {id: string; value?: unknown; error?: string};
type CommunityProps = ViewProps & {
  reply?: Reply;
  onSignal: (event: NativeSyntheticEvent<Signal>) => void;
};

const LocalPage = requireNativeComponent<CommunityProps>('NinaCommunity');

function lineCard(item: Line) {
  const {activeID, archive} = library.snapshot();
  const account = activeID && archive.accounts[activeID];
  if (!account || isReported(account, {kind: 'line', id: item.id})) {
    return null;
  }
  const comments = archive.comments.flatMap(comment => {
    if (comment.lineID !== item.id || isReported(account, {kind: 'comment', id: comment.id})) {
      return [];
    }
    const author = visibleSkater(archive, account, comment.authorID);
    return author ? [{name: author.profile.name, body: comment.body}] : [];
  });
  const filename = mediaFilename(item.poster ?? item.path);
  return {
    id: item.id, title: item.title, type: item.type, collection: item.collection,
    label: collectionNames[item.collection],
    image: filename ? `media/${filename}` : null,
    liked: account.liked.includes(item.id), saved: account.saved.includes(item.id), comments,
  };
}

function communityState() {
  const {activeID, archive, warning} = library.snapshot();
  const member = activeID && archive.accounts[activeID];
  return {
    name: member ? member.profile.name : null,
    warning: warning ?? null,
    lines: member ? lines.map(lineCard).filter(card => card !== null) : [],
  };
}

function requestText(data: unknown, key: string) {
  const value = data && typeof data === 'object' ? (data as Record<string, unknown>)[key] : undefined;
  return typeof value === 'string' ? value : '';
}

export function OfflineCommunity({onJournal, onApple}: {
  onJournal: (destination: JournalDestination) => void;
  onApple: () => void;
}) {
  const safe = useSafeAreaInsets();
  const viewport = useWindowBounds();
  const {regions} = useWindowLayout();
  const [revision, reload] = useState(0);
  const [status, setStatus] = useState<'loading' | 'loaded' | 'failed'>('loading');
  const [reply, setReply] = useState<Reply>();
  const [policy, setPolicy] = useState<Policy>();
  let [left, right, top, bottom] = [safe.left, safe.right, safe.top, safe.bottom];
  const bounds = viewport.bounds;
  if (bounds) {
    const columns = regions.filter(region => region.height >= bounds.height * 0.7);
    const rows = regions.filter(region => region.width >= bounds.width * 0.7);
    const transpose = ({x, y, width, height}: Rect) => ({x: y, y: x, width: height, height: width});
    [left, right] = freeBand(bounds, columns, left, right);
    [top, bottom] = freeBand(transpose(bounds), rows.map(transpose), top, bottom);
  }

  async function handle(action: string, data: unknown) {
    switch (action) {
      case 'snapshot':
        return communityState();
      case 'register':
      case 'signIn':
        if (requestText(data, 'consent') !== 'agreed') {
          throw new Error('Accept the Terms and Privacy Policy to continue.');
        }
        await library.signIn(requestText(data, 'email'), requestText(data, 'password'), action === 'register');
        return communityState();
      case 'signOut':
        await library.signOut();
        return communityState();
      case 'apple':
        onApple();
        return null;
      case 'policy': {
        const name = requestText(data, 'name');
        if (name !== 'terms' && name !== 'privacy' && name !== 'rules') {
          throw new Error('This document is unavailable.');
        }
        setPolicy(name);
        return null;
      }
      case 'journal': {
        if (!library.snapshot().activeID) {
          throw new Error('Sign in to open your journal.');
        }
        const tab = requestText(data, 'tab');
        if (tab !== 'lines' && tab !== 'sessions' && tab !== 'crew') {
          throw new Error('This journal page is unavailable.');
        }
        const line = findLine(requestText(data, 'id'));
        const route: Route | undefined = line && lineCard(line) ? {name: 'line', id: line.id} : undefined;
        onJournal({tab, route});
        return null;
      }
      case 'like':
      case 'save':
      case 'comment': {
        const line = findLine(requestText(data, 'id'));
        if (!line || !lineCard(line)) {
          throw new Error('This line is unavailable.');
        }
        if (action === 'comment') {
          await library.saveComment(line.id, requestText(data, 'body'));
        } else {
          await library.toggleLine(line.id, action === 'like' ? 'liked' : 'saved');
        }
        return lineCard(line);
      }
      default:
        throw new Error('This community action is unavailable.');
    }
  }

  function signal({nativeEvent}: NativeSyntheticEvent<Signal>) {
    if (nativeEvent.status !== 'request') {
      setStatus(nativeEvent.status);
      return;
    }
    const {id, action, data} = nativeEvent;
    void handle(action, data).then(
      value => setReply({id, value}),
      error => setReply({id, error: errorText(error)}),
    );
  }

  return <View style={[layout.fill, layout.paper]}>
    <View
      ref={viewport.ref}
      onLayout={viewport.measure}
      collapsable={false}
      style={[layout.fill, {paddingTop: top, paddingBottom: bottom, paddingLeft: left, paddingRight: right}]}
      accessibilityElementsHidden={Boolean(policy)}
    >
      <LocalPage key={revision} style={layout.fill} onSignal={signal} reply={reply} />
    </View>
    {status !== 'loaded' ? <View style={communityStyles.loading} accessibilityViewIsModal>
      <Glyph name={status === 'failed' ? 'ramp' : 'load'} size={44} />
      <Copy size="heading" header>{status === 'failed' ? 'Could not open the community' : 'Opening Nina'}</Copy>
      {status === 'failed' ? <Action title="Try again" icon="load" action={() => {
        setReply(undefined);
        setStatus('loading');
        reload(value => value + 1);
      }} /> : null}
    </View> : null}
    {policy ? <View style={StyleSheet.absoluteFill} accessibilityViewIsModal>
      <WebPageScreen key={policy} page={policy} close={() => setPolicy(undefined)} />
    </View> : null}
  </View>;
}

const communityStyles = StyleSheet.create({
  loading: {
    ...StyleSheet.absoluteFillObject, backgroundColor: colors.paper,
    alignItems: 'center', justifyContent: 'center', padding: 20, gap: 10,
  },
});
