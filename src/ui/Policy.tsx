import React, {useState} from 'react';
import {StyleSheet, View} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import {NativeSurface} from '../native';
import type {Policy} from '../native';
import {ActionBand} from './geometry';
import {Action, colors, Copy, IconAction, layout, Notice} from './paper';

export const policyTitles: Record<Policy, string> = {terms: 'Terms of Use', privacy: 'Privacy Policy', rules: 'Crew Rules'};

export function PolicyPage({policy, close}: {policy: Policy; close(): void}) {
  const safe = useSafeAreaInsets();
  const [status, setStatus] = useState<'loading' | 'loaded' | 'failed'>('loading');
  const [revision, setRevision] = useState(0);
  return <View style={[layout.fill, layout.paper, {paddingTop: safe.top, paddingBottom: safe.bottom, paddingLeft: safe.left, paddingRight: safe.right}]}>
    <ActionBand>
      <View style={styles.bar}>
        <IconAction title="Close policy" icon="close" action={close} />
        <Copy size="card" header>{policyTitles[policy]}</Copy>
      </View>
    </ActionBand>
    {status === 'loading' && <Notice>Opening {policyTitles[policy]}…</Notice>}
    {status === 'failed' && <View style={layout.section}>
      <Notice error>Couldn’t open {policyTitles[policy]}.</Notice>
      <Action title="Try again" icon="load" action={() => {setStatus('loading'); setRevision(value => value + 1);}} />
    </View>}
    <NativeSurface style={layout.fill} kind="policy" policy={policy} revision={revision}
      onSignal={({nativeEvent}) => {
        if (nativeEvent.status !== 'pressed') {
          setStatus(nativeEvent.status);
        }
      }} />
  </View>;
}

const styles = StyleSheet.create({
  bar: {flexDirection: 'row', alignItems: 'center', minHeight: 55, gap: 10, backgroundColor: colors.paper},
});
