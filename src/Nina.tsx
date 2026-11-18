import React, {useEffect, useState} from 'react';
import {AppState, Keyboard, Pressable, StatusBar, StyleSheet, View} from 'react-native';
import {initialWindowMetrics, SafeAreaProvider, useSafeAreaInsets} from 'react-native-safe-area-context';
import {onAppleRevocation, onPurchase, platform} from './native';
import {FlowContext} from './navigation';
import type {Route, Tab} from './navigation';
import {CallWaiting} from './screens/Call';
import {Crew, ProfileDetails, ProfileEditor, Relationships} from './screens/Crew';
import {LineDetails, Lines, LineViewer} from './screens/Lines';
import {Conversation, Messages} from './screens/Messages';
import {OfflineCommunity} from './screens/OfflineCommunity';
import type {JournalDestination} from './screens/OfflineCommunity';
import {Blacklist, Block, DeleteProfile, Report, Settings} from './screens/Safety';
import {Sessions, SpotDetails, SpotEditor, TrickEditor} from './screens/Sessions';
import {PostEditor, Submissions, SubmissionViewer} from './screens/Submissions';
import {CoverShop, Wallet} from './screens/Wallet';
import {OpeningJournal} from './screens/Welcome';
import {library, useJournal} from './state/library';
import {recordID} from './state/model';
import {deliver} from './state/purchases';
import {ActionBand, WindowLayoutProvider} from './ui/geometry';
import {observeFilm} from './ui/media';
import {colors, Copy, Glyph, IconAction, layout} from './ui/paper';
import {WebPageScreen} from './ui/WebPage';

export default function Nina() {
  return <SafeAreaProvider initialMetrics={initialWindowMetrics}>
    <WindowLayoutProvider>
      <StatusBar barStyle="dark-content" />
      <Entry />
    </WindowLayoutProvider>
  </SafeAreaProvider>;
}

function Entry() {
  const {status, config, activeID} = useJournal();
  const [destination, setDestination] = useState<'community' | JournalDestination>('community');
  const showCommunity = () => setDestination('community');
  useEffect(() => {
    const film = observeFilm();
    const revocation = onAppleRevocation(() => {void library.signOut(true).catch(() => {});});
    const app = AppState.addEventListener('change', value => {
      if (value !== 'active') {pauseFilm();}
    });
    void library.load();
    return () => {
      film.remove();
      revocation.remove();
      app.remove();
      pauseFilm();
    };
  }, []);
  useEffect(() => {
    if (!config?.purchasesEnabled || status !== 'ready') {
      return;
    }
    const subscription = onPurchase(transaction => {void deliver(transaction).catch(() => {});});
    void platform('startPurchases').then(async unfinished => {
      for (const transaction of unfinished) {
        await deliver(transaction).catch(() => {});
      }
    }).catch(() => {});
    return () => subscription.remove();
  }, [status, config?.purchasesEnabled]);
  useEffect(() => {
    setDestination(current => {
      if (typeof current !== 'string' && !activeID) {
        return 'community';
      }
      return current;
    });
  }, [activeID]);
  if (status !== 'ready') {
    return <OpeningJournal />;
  }
  if (typeof destination !== 'string' && activeID) {
    return <Journal key={activeID} destination={destination} onCommunity={showCommunity} />;
  }
  return <OfflineCommunity key={activeID ?? 'guest'} onJournal={setDestination} />;
}

function pauseFilm() {
  void platform('pauseFilm').catch(() => {});
}

type RouteEntry = {key: string; route: Route};
type NavigationState = {tab: Tab; stacks: Record<Tab, RouteEntry[]>};
const tabs = [
  {id: 'lines', name: 'Lines'}, {id: 'sessions', name: 'Sessions'}, {id: 'crew', name: 'Crew'},
] as const;
const emptyStacks = () => ({lines: [], sessions: [], crew: []});

function Journal({destination, onCommunity}: {destination: JournalDestination; onCommunity: () => void}) {
  const safe = useSafeAreaInsets();
  const [nav, setNav] = useState<NavigationState>(() => ({
    tab: destination.tab,
    stacks: {
      ...emptyStacks(),
      [destination.tab]: destination.route ? [{key: recordID(), route: destination.route}] : [],
    },
  }));
  const [notice, setNotice] = useState('');
  const [noticeHeight, setNoticeHeight] = useState(0);
  const currentStack = nav.stacks[nav.tab];
  const currentRoute = currentStack[currentStack.length - 1]?.route.name;
  const immersive = currentRoute === 'lineViewer' || currentRoute === 'submissionViewer' || currentRoute === 'call';

  function activate(tab: Tab) {
    setNotice('');
    pauseFilm();
    Keyboard.dismiss();
    setNav(current => current.tab === tab ? current : {...current, tab});
  }

  function open(tab: Tab, routeKey: string | undefined, route: Route) {
    pauseFilm();
    Keyboard.dismiss();
    setNotice('');
    const entry = {key: recordID(), route};
    setNav(current => {
      const entries = current.stacks[tab];
      if (current.tab !== tab || entries[entries.length - 1]?.key !== routeKey) {
        return current;
      }
      return {...current, stacks: {...current.stacks, [tab]: [...entries, entry]}};
    });
  }

  function back(tab: Tab, key: string | undefined) {
    if (!key) {
      return;
    }
    pauseFilm();
    Keyboard.dismiss();
    setNotice('');
    setNav(current => {
      const entries = current.stacks[tab];
      if (current.tab !== tab || entries[entries.length - 1]?.key !== key) {
        return current;
      }
      return {...current, stacks: {...current.stacks, [tab]: entries.slice(0, -1)}};
    });
  }

  function element(tab: Tab, key: string | undefined, visible: boolean, child: React.ReactNode) {
    return <FlowContext.Provider key={key ?? tab} value={{
      visible,
      open: route => open(tab, key, route),
      back: () => back(tab, key),
      select: activate,
      notice: setNotice,
    }}>
      <View style={[StyleSheet.absoluteFill, !visible && styles.hidden]} pointerEvents={visible ? 'auto' : 'none'}
        accessibilityElementsHidden={!visible} importantForAccessibility={visible ? 'auto' : 'no-hide-descendants'}>
        {child}
      </View>
    </FlowContext.Provider>;
  }

  return <View style={[layout.fill, layout.paper]}>
    <View style={[layout.fill, notice ? {marginTop: noticeHeight} : null]}>
      {tabs.map(({id}) => {
        const stack = nav.stacks[id];
        const last = stack[stack.length - 1];
        return <React.Fragment key={id}>
          {element(id, undefined, nav.tab === id && !last, <>
            <View style={layout.fill}>{tabScreen(id)}</View>
            <Dock selected={nav.tab} activate={activate} onCommunity={() => {
              pauseFilm();
              Keyboard.dismiss();
              onCommunity();
            }} />
          </>)}
          {stack.map(entry => element(id, entry.key, nav.tab === id && last?.key === entry.key, routeScreen(entry.route, () => back(id, entry.key))))}
        </React.Fragment>;
      })}
    </View>
    {notice ? <View
      onLayout={event => setNoticeHeight(event.nativeEvent.layout.height)}
      style={[styles.noticeBar, {top: safe.top, left: safe.left, right: safe.right}]}
    >
      <ActionBand minimumWidth={150}>
        <View style={styles.noticeContent} accessibilityLiveRegion="polite">
          <Copy size="label" style={layout.fill}>{notice}</Copy>
          <IconAction title="Dismiss message" icon="close" action={() => setNotice('')} />
        </View>
      </ActionBand>
    </View> : null}
    <StatusBar barStyle={immersive ? 'light-content' : 'dark-content'} />
  </View>;
}

function Dock({selected, activate, onCommunity}: {selected: Tab; activate(tab: Tab): void; onCommunity: () => void}) {
  return <View style={layout.ink}>
    <ActionBand edge="bottom" minimumWidth={201}>
      <View style={styles.dock}>
        <Pressable accessibilityRole="button" accessibilityLabel="Back to community" onPress={onCommunity}
          style={({pressed}) => [styles.tab, {opacity: pressed ? 0.73 : 1}]}>
          <Glyph name="back" size={21} color={colors.paper} />
          <Copy size="caption" color={colors.paper} limit={1}>Community</Copy>
        </Pressable>
        {tabs.map(item => {
          const active = selected === item.id;
          const tint = active ? colors.ink : colors.paper;
          return <Pressable key={item.id} accessibilityRole="tab" accessibilityState={{selected: active}}
            onPress={() => activate(item.id)}
            style={({pressed}) => [styles.tab, {
              backgroundColor: active ? colors.grip : colors.ink, opacity: pressed ? 0.73 : 1,
            }]}>
            <Glyph name={item.id} size={21} color={tint} />
            <Copy size="caption" color={tint} limit={1}>{item.name}</Copy>
          </Pressable>;
        })}
      </View>
    </ActionBand>
  </View>;
}

function tabScreen(tab: Tab) {
  switch (tab) {
    case 'lines': return <Lines />;
    case 'sessions': return <Sessions />;
    case 'crew': return <Crew />;
  }
}

function routeScreen(route: Route, close: () => void) {
  switch (route.name) {
    case 'line': return <LineDetails id={route.id} />;
    case 'lineViewer': return <LineViewer id={route.id} />;
    case 'post': return <PostEditor id={route.id} />;
    case 'submissions': return <Submissions />;
    case 'submissionViewer': return <SubmissionViewer id={route.id} />;
    case 'spotEditor': return <SpotEditor id={route.id} reference={route.reference} />;
    case 'spot': return <SpotDetails id={route.id} />;
    case 'trick': return <TrickEditor id={route.id} spot={route.spot} reference={route.reference} />;
    case 'crewAtSpot': return <Crew spotKey={route.spotKey} title={route.title} />;
    case 'profile': return <ProfileDetails id={route.id} />;
    case 'profileEditor': return <ProfileEditor />;
    case 'relationships': return <Relationships id={route.id} incoming={route.incoming} />;
    case 'messages': return <Messages />;
    case 'conversation': return <Conversation id={route.id} />;
    case 'call': return <CallWaiting id={route.id} video={route.video} />;
    case 'report': return <Report subject={route.subject} />;
    case 'block': return <Block id={route.id} />;
    case 'blacklist': return <Blacklist />;
    case 'settings': return <Settings />;
    case 'webPage': return <WebPageScreen page={route.page} close={close} />;
    case 'deleteProfile': return <DeleteProfile />;
    case 'wallet': return <Wallet />;
    case 'covers': return <CoverShop />;
  }
}

const styles = StyleSheet.create({
  hidden: {opacity: 0},
  noticeBar: {position: 'absolute', backgroundColor: colors.paper},
  noticeContent: {flexDirection: 'row', alignItems: 'center', gap: 9, minHeight: 47},
  dock: {minHeight: 61, flexDirection: 'row', alignItems: 'center', gap: 3},
  tab: {minWidth: 44, minHeight: 46, flexGrow: 1, flexBasis: 0, paddingVertical: 4, justifyContent: 'center', alignItems: 'center', gap: 2},
});
