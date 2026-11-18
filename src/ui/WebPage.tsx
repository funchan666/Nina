import React, {useState} from 'react';
import {StyleSheet, View} from 'react-native';
import {NativeSurface} from '../native';
import type {WebPage} from '../native';
import {ActionBand} from './geometry';
import {Action, colors, Copy, IconAction, layout, Notice} from './paper';

export const webPageTitles: Record<WebPage, string> = {
  website: 'Official Website',
  terms: 'Terms of Use',
  privacy: 'Privacy Policy',
  rules: 'Crew Rules',
};

export function WebPageScreen({page, close}: {page: WebPage; close(): void}) {
  const title = webPageTitles[page];
  const [status, setStatus] = useState<'loading' | 'loaded' | 'failed'>('loading');
  const [revision, setRevision] = useState(0);
  return <View style={[layout.fill, layout.paper]}>
    <ActionBand edge="top">
      <View style={styles.bar}>
        <IconAction title={`Close ${title}`} icon="close" action={close} />
        <Copy size="card" header style={layout.fill}>{title}</Copy>
      </View>
    </ActionBand>
    {status === 'loading' && <Notice>Opening {title}…</Notice>}
    {status === 'failed' && <View style={layout.section}>
      <Notice error>Couldn’t open {title}.</Notice>
      <Action title="Try again" icon="load" action={() => {setStatus('loading'); setRevision(value => value + 1);}} />
    </View>}
    <NativeSurface style={layout.fill} kind="web" page={page} revision={revision}
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
