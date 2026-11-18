import React, {useEffect, useMemo, useRef, useState} from 'react';
import {Linking, PanResponder, StyleSheet, View} from 'react-native';
import {NativeSurface, onCallStopped, platform} from '../native';
import type {Rect} from '../native';
import {errorText, useFlow} from '../navigation';
import {canContact, library, useSkater, visibleSkater} from '../state/library';
import {recordID} from '../state/model';
import type {ID} from '../state/model';
import {ActionBand, intersects, useWindowBounds, useWindowLayout} from '../ui/geometry';
import {Action, colors, Copy, Glyph, IconAction, layout} from '../ui/paper';

type CallPhase = {kind: 'preparing' | 'waiting' | 'ended' | 'denied'; message: string};

export function CallWaiting({id, video}: {id: ID; video: boolean}) {
  const flow = useFlow();
  const {archive, account} = useSkater();
  const peer = visibleSkater(archive, account, id);
  const [requestID] = useState(recordID);
  const [phase, setPhase] = useState<CallPhase>({kind: 'preparing', message: 'Checking access…'});
  useEffect(() => {
    const snapshot = library.snapshot();
    const viewer = snapshot.activeID && snapshot.archive.accounts[snapshot.activeID];
    if (!viewer || !canContact(snapshot.archive, viewer, id)) {
      setPhase({kind: 'ended', message: 'Both skaters must follow each other to open call waiting.'});
      return;
    }
    let active = true;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const stop = () => {void platform('stopCall', {requestID}).catch(() => {});};
    const subscription = onCallStopped(() => {
      active = false;
      if (timer) {clearTimeout(timer);}
      setPhase({kind: 'ended', message: 'Waiting ended when the app went into the background.'});
    });
    void platform('beginCall', {video, requestID}).then(() => {
      if (!active) {
        stop();
        return;
      }
      setPhase({kind: 'waiting', message: video ? 'Camera and microphone ready.' : 'Microphone ready.'});
      timer = setTimeout(() => {
        stop();
        setPhase({kind: 'ended', message: 'The waiting window ended.'});
      }, 25_000);
    }).catch(error => {
      if (active) {
        const message = errorText(error);
        setPhase({kind: message.includes('Settings') ? 'denied' : 'ended', message});
      }
    });
    return () => {
      active = false;
      if (timer) {clearTimeout(timer);}
      subscription.remove();
      stop();
    };
  }, [id, requestID, video]);

  return <View style={[layout.fill, layout.ink]}>
    <ActionBand edge="top">
      <View style={styles.top}>
        <IconAction title="Close call" icon="close" color={colors.paper} action={flow.back} />
        <Copy size="card" color={colors.paper} header>{video ? 'Video call' : 'Voice call'}</Copy>
      </View>
    </ActionBand>
    <View style={styles.copy}>
      {peer && <Copy size="heading" color={colors.paper}>{peer.profile.name}</Copy>}
      <Copy color={colors.paper}>{phase.message}</Copy>
      {phase.kind === 'denied' && <Action title="Open iPhone Settings" icon="settings" tone="paper"
        action={() => {void Linking.openSettings().catch(() => {});}} />}
    </View>
    {phase.kind === 'waiting' && video ? <CameraPreview /> :
      <View style={styles.waiting}>
        <Glyph name={phase.kind === 'preparing' ? 'load' : video ? 'video' : 'phone'} size={63} color={colors.grip} />
      </View>}
    <ActionBand edge="bottom">
      <View style={styles.close}>
        <Action title="Close waiting" icon="close" tone="danger" action={flow.back} />
      </View>
    </ActionBand>
  </View>;
}

type Point = {x: number; y: number};
const initial: Point = {x: 0.92, y: 0.78};
const zero: Point = {x: 0, y: 0};

function closestPosition(target: Point, space: Rect, tile: {width: number; height: number}, regions: Rect[]): Point | undefined {
  const dx = Math.max(0, space.width - tile.width);
  const dy = Math.max(0, space.height - tile.height);
  const local = regions.filter(region => intersects(space, region)).map(region => ({
    x: region.x - space.x, y: region.y - space.y, width: region.width, height: region.height,
  }));
  const xs = [target.x, 0, dx, ...local.flatMap(region => [region.x - tile.width - 4, region.x + region.width + 4])];
  const ys = [target.y, 0, dy, ...local.flatMap(region => [region.y - tile.height - 4, region.y + region.height + 4])];
  const results = xs.flatMap(x => ys.map(y => ({x: Math.max(0, Math.min(dx, x)), y: Math.max(0, Math.min(dy, y))})));
  return results.filter(point => !local.some(region => intersects({...point, ...tile}, region)))
    .sort((a, b) => Math.hypot(a.x - target.x, a.y - target.y) - Math.hypot(b.x - target.x, b.y - target.y))[0];
}

function CameraPreview() {
  const {ref, bounds, measure} = useWindowBounds();
  const {regions} = useWindowLayout();
  const [anchor, setAnchor] = useState(initial);
  const [delta, setDelta] = useState(zero);
  const width = Math.min(152, Math.max(0, (bounds?.width ?? 0) - 16));
  const height = Math.min(width * 1.22, Math.max(0, (bounds?.height ?? 0) - 16));
  const dx = Math.max(1, (bounds?.width ?? 0) - width);
  const dy = Math.max(1, (bounds?.height ?? 0) - height);
  const desired = {x: anchor.x * dx + delta.x, y: anchor.y * dy + delta.y};
  const position = bounds && width >= 48 && height >= 48
    ? closestPosition(desired, bounds, {width, height}, regions) : undefined;
  const geometry = useRef({bounds, regions, width, height, dx, dy, anchor});
  geometry.current = {bounds, regions, width, height, dx, dy, anchor};
  const pan = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onPanResponderMove: (_, movement) => setDelta({x: movement.dx, y: movement.dy}),
    onPanResponderRelease: (_, movement) => {
      const current = geometry.current;
      if (current.bounds) {
        const target = {x: current.anchor.x * current.dx + movement.dx, y: current.anchor.y * current.dy + movement.dy};
        const next = closestPosition(target, current.bounds, {width: current.width, height: current.height}, current.regions);
        if (next) {setAnchor({x: next.x / current.dx, y: next.y / current.dy});}
      }
      setDelta(zero);
    },
    onPanResponderTerminate: () => setDelta(zero),
  }), []);
  return <View style={layout.fill} ref={ref} collapsable={false} onLayout={measure}>
    {position ? <View
      style={[styles.preview, {width, height, left: position.x, top: position.y}]}
      accessible accessibilityLabel="Your camera" accessibilityHint="Drag to move within the available area"
      {...pan.panHandlers}
    >
      <NativeSurface kind="camera" style={layout.fill} pointerEvents="none" />
      <Copy size="caption" color={colors.paper} style={styles.previewLabel}>Your camera</Copy>
    </View> : <Copy color={colors.paper} style={styles.copy}>Open more space to see your camera.</Copy>}
  </View>;
}

const styles = StyleSheet.create({
  top: {minHeight: 56, flexDirection: 'row', alignItems: 'center', gap: 8},
  copy: {width: '100%', maxWidth: 680, alignSelf: 'center', paddingHorizontal: 16, paddingVertical: 9, gap: 6},
  waiting: {flex: 1, alignItems: 'center', justifyContent: 'center'},
  close: {minHeight: 64, alignItems: 'center', justifyContent: 'center'},
  preview: {position: 'absolute', overflow: 'hidden', backgroundColor: colors.ink},
  previewLabel: {position: 'absolute', left: 0, bottom: 0, padding: 6, backgroundColor: colors.ink},
});
