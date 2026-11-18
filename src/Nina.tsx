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
import {library, useJournal, useSkater, visibleActivity} from './state/library';
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
  if (status !== 'ready') {
    return <OpeningJournal />;
  }
  return activeID ? <Journal key={activeID} /> : <OfflineCommunity key="guest" />;
}

function pauseFilm() {
  void platform('pauseFilm').catch(() => {});
}

type RouteEntry = {key: string; route: Route};
type NavigationState = {tab: Tab; stacks: Record<Tab, RouteEntry[]>};
const tabs = [
  {id: 'lines', name: 'Discover', icon: 'lines'},
  {id: 'sessions', name: 'Sessions', icon: 'sessions'},
  {id: 'crew', name: 'Crew', icon: 'crew'},
  {id: 'messages', name: 'Inbox', icon: 'comment'},
  {id: 'profile', name: 'You', icon: 'avatar'},
] as const;
const emptyStacks = () => ({lines: [], sessions: [], crew: [], messages: [], profile: []});

function Journal() {
  const safe = useSafeAreaInsets();
  const [nav, setNav] = useState<NavigationState>(() => ({
    tab: 'lines',
    stacks: emptyStacks(),
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

  function navigate({tab, route}: JournalDestination) {
    pauseFilm();
    Keyboard.dismiss();
    setNotice('');
    setNav(current => ({...current, tab, stacks: route
      ? {...current.stacks, [tab]: [...current.stacks[tab], {key: recordID(), route}]}
      : current.stacks}));
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
          {element(id, undefined, nav.tab === id && !last,
            tabScreen(id, nav.tab === id && !last, navigate))}
          {stack.map(entry => element(id, entry.key, nav.tab === id && last?.key === entry.key, routeScreen(entry.route, () => back(id, entry.key))))}
        </React.Fragment>;
      })}
    </View>
    {!currentStack.length && <Dock selected={nav.tab} activate={activate} />}
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

function Dock({selected, activate}: {selected: Tab; activate(tab: Tab): void}) {
  const {archive, account} = useSkater();
  const unread = visibleActivity(archive, account).filter(item => !item.read).length;
  return <View style={layout.paper}>
    <ActionBand edge="bottom" minimumWidth={260}>
      <View style={styles.dock} accessibilityRole="tablist" accessibilityLabel="Main navigation">
        {tabs.map(item => {
          const active = selected === item.id;
          const tint = active ? colors.ink : colors.muted;
          return <Pressable key={item.id} accessibilityRole="tab" accessibilityState={{selected: active}}
            accessibilityLabel={item.id === 'messages' && unread ? `Inbox, ${unread} unread updates` : item.name}
            onPress={() => activate(item.id)}
            style={({pressed}) => [styles.tab, {
              opacity: pressed ? 0.73 : 1,
            }]}>
            <View style={[styles.tabIcon, active && {backgroundColor: colors.grip}]}>
              <Glyph name={item.icon} size={23} color={tint} />
              {item.id === 'messages' && unread > 0 ? <View style={styles.badge}>
                <Copy size="caption" color={colors.paper} style={{fontSize: 10}}>{unread > 99 ? '99+' : unread}</Copy>
              </View> : null}
            </View>
            <Copy size="caption" color={tint} style={{fontSize: 12}} limit={1}>{item.name}</Copy>
          </Pressable>;
        })}
      </View>
    </ActionBand>
  </View>;
}

function tabScreen(tab: Tab, visible: boolean, navigate: (destination: JournalDestination) => void) {
  switch (tab) {
    case 'lines': return <OfflineCommunity active={visible} onJournal={navigate} />;
    case 'sessions': return <Sessions />;
    case 'crew': return <Crew />;
    case 'messages': return <Messages root />;
    case 'profile': return <ProfileHome />;
  }
}

function ProfileHome() {
  const {account} = useSkater();
  return <ProfileDetails id={account.id} root />;
}

function routeScreen(route: Route, close: () => void) {
  switch (route.name) {
    case 'collection': return <Lines root={false} />;
    case 'savedLines': return <Lines root={false} savedOnly />;
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
  dock: {minHeight: 72, flexDirection: 'row', alignItems: 'center', gap: 3, paddingVertical: 5},
  tab: {minWidth: 44, minHeight: 60, flexGrow: 1, flexBasis: 0, justifyContent: 'center', alignItems: 'center', gap: 3},
  tabIcon: {minWidth: 47, paddingHorizontal: 12, paddingVertical: 5, borderRadius: 12, alignItems: 'center'},
  badge: {position: 'absolute', right: -1, top: -3, minWidth: 17, paddingHorizontal: 4, borderRadius: 8, backgroundColor: colors.oxide, alignItems: 'center'},
});
