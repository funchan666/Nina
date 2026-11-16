import React, {useEffect, useState, useSyncExternalStore} from 'react';
import {Image, StyleSheet, View} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import {NativeSurface, onFilmChange, platform} from '../native';
import type {FilmState} from '../native';
import {errorText, useFlow} from '../navigation';
import {ActionBand} from './geometry';
import {Action, colors, Copy, Glyph, IconAction, layout} from './paper';

const idle: FilmState = {engaged: false, playing: false, muted: false, loading: false, failed: false, time: 0, duration: 0};
let film = idle;
const listeners = new Set<() => void>();
export function observeFilm() {
  return onFilmChange(state => {
    film = state;
    listeners.forEach(notify => notify());
  });
}
function subscribe(notify: () => void) {
  listeners.add(notify);
  return () => listeners.delete(notify);
}
const snapshot = () => film;

export function useFilm() {
  return useSyncExternalStore(subscribe, snapshot);
}

export function timeText(seconds: number) {
  const total = Number.isFinite(seconds) ? Math.max(0, Math.floor(seconds)) : 0;
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

export function Poster({uri, label, retry, contain, revision = 0}: {
  uri?: string; label: string; retry?: boolean; contain?: boolean; revision?: number;
}) {
  const [status, setStatus] = useState<'loading' | 'failed' | 'loaded'>('loading');
  const [reload, setReload] = useState(0);
  useEffect(() => { setStatus('loading'); }, [uri, revision, reload]);
  return <View style={styles.poster}>
    {uri ? <Image
      key={`${uri}:${revision}:${reload}`}
      source={{uri, cache: revision || reload ? 'reload' : 'default'}}
      resizeMode={contain ? 'contain' : 'cover'}
      style={styles.posterImage}
      accessible={status === 'loaded'}
      accessibilityLabel={label}
      onLoad={() => setStatus('loaded')}
      onError={() => setStatus('failed')}
    /> : null}
    {(!uri || status === 'failed') && <View style={styles.placeholder}>
      <Glyph name="ramp" size={34} />
      <Copy size="caption">Image unavailable</Copy>
      {uri && retry ? <Action title="Retry" icon="load" tone="paper" action={() => setReload(value => value + 1)} /> : null}
    </View>}
    {uri && status === 'loading' && <View style={styles.placeholder} pointerEvents="none"
      accessible accessibilityLabel="Loading image" accessibilityRole="progressbar">
      <Glyph name="load" size={32} />
    </View>}
  </View>;
}

function Scrubber({state}: {state: FilmState}) {
  const [width, setWidth] = useState(0);
  const fraction = Math.max(0, Math.min(1, state.time / state.duration));
  const track = Math.max(1, width - 20);
  function seek(seconds: number) {
    void platform('seekFilm', {seconds}).catch(() => {});
  }
  return <View
    style={styles.scrubber}
    accessible accessibilityRole="adjustable" accessibilityLabel="Film position"
    accessibilityValue={{text: `${timeText(state.time)} of ${timeText(state.duration)}`}}
    accessibilityActions={[{name: 'increment'}, {name: 'decrement'}]}
    onAccessibilityAction={({nativeEvent}) => {
      seek(state.time + (nativeEvent.actionName === 'increment' ? 5 : -5));
    }}
    onLayout={event => setWidth(event.nativeEvent.layout.width)}
    onStartShouldSetResponder={() => true}
    onResponderRelease={event => {
      const ratio = Math.max(0, Math.min(1, (event.nativeEvent.locationX - 10) / track));
      seek(ratio * state.duration);
    }}
  >
    <View style={styles.track} pointerEvents="none">
      <View style={{height: 3, width: track * fraction + 10, backgroundColor: colors.grip}} />
    </View>
    <View style={{position: 'absolute', left: track * fraction}} pointerEvents="none">
      <Glyph name="thumb" size={20} color={colors.grip} />
    </View>
  </View>;
}

export function Film({id, uri, poster, title, fullscreen, expand, report}: {
  id: string; uri?: string; poster?: string; title: string; fullscreen?: boolean; expand?: () => void; report?: () => void;
}) {
  const state = useFilm();
  const flow = useFlow();
  const selected = flow.visible && state.id === id;
  const playing = selected && state.playing;
  function play() {
    if (uri) {
      void platform('playFilm', {id, uri}).catch(error => flow.notice(errorText(error)));
    }
  }
  return <View style={fullscreen ? layout.fill : undefined}>
    <View style={fullscreen ? layout.fill : styles.filmStage}>
      {selected && state.engaged && !state.failed ? <NativeSurface kind="film" style={layout.fill} /> :
        <Poster uri={poster} label={title} contain />}
      {playing && state.loading ? <View style={styles.placeholder} pointerEvents="none">
        <Copy color={colors.paper} style={styles.buffer}>Buffering film…</Copy>
      </View> : null}
      {!playing && uri ? <View style={styles.placeholder} pointerEvents="box-none">
        {selected && state.failed ? <Action title="Retry film" icon="load" action={play} /> :
          <IconAction title={'Play ' + title} icon="play" fill={colors.grip} action={play} />}
      </View> : null}
    </View>
    <ActionBand minimumWidth={190} style={{backgroundColor: colors.ink}}>
      <View style={styles.controls}>
        {uri ? <IconAction title={playing ? 'Pause' : 'Play'} icon={playing ? 'pause' : 'play'}
          color={colors.paper} action={play} /> : null}
        {selected && state.duration > 0 ?
          <Scrubber state={state} /> :
          <Copy size="caption" color={colors.paper} style={layout.fill}>{uri ? 'Film' : 'Film unavailable'}</Copy>}
        {uri ? <IconAction title={state.muted ? 'Unmute' : 'Mute'} icon={state.muted ? 'muted' : 'speaker'}
          color={colors.paper} action={() => {void platform('muteFilm').catch(() => {});}} /> : null}
        {expand ? <IconAction title="Full screen" icon="expand" color={colors.paper} action={expand} /> : null}
        {report ? <IconAction title="Report film" icon="flag" color={colors.paper} action={report} /> : null}
      </View>
    </ActionBand>
  </View>;
}

export function MediaStage({title, children}: {title: string; children: React.ReactNode}) {
  const safe = useSafeAreaInsets();
  const flow = useFlow();
  return <View style={[layout.fill, layout.ink, {paddingTop: safe.top, paddingBottom: safe.bottom, paddingLeft: safe.left, paddingRight: safe.right}]}>
    <ActionBand>
      <View style={styles.mediaBar}>
        <IconAction title="Close media" icon="close" color={colors.paper} action={flow.back} />
        <Copy size="label" color={colors.paper} limit={2} style={layout.fill}>{title}</Copy>
      </View>
    </ActionBand>
    <View style={layout.fill}>{children}</View>
  </View>;
}

const styles = StyleSheet.create({
  poster: {flex: 1, backgroundColor: colors.sage, overflow: 'hidden'},
  posterImage: {...StyleSheet.absoluteFillObject, width: '100%', height: '100%'},
  placeholder: {...StyleSheet.absoluteFillObject, alignItems: 'center', justifyContent: 'center', gap: 6},
  filmStage: {height: 312, backgroundColor: colors.ink},
  buffer: {backgroundColor: colors.ink, padding: 8},
  controls: {minHeight: 48, gap: 2, flexDirection: 'row', alignItems: 'center'},
  scrubber: {flex: 1, minWidth: 30, minHeight: 44, justifyContent: 'center'},
  track: {height: 3, backgroundColor: '#647169'},
  mediaBar: {minHeight: 54, alignItems: 'center', flexDirection: 'row', gap: 8},
});
