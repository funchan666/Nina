import React from 'react';
import {StatusBar, StyleSheet, View} from 'react-native';
import {library, useJournal} from '../state/library';
import {Action, colors, Copy, Glyph} from '../ui/paper';

export function OpeningJournal() {
  const {status, issue} = useJournal();
  return <View style={styles.startup}>
    <StatusBar barStyle="light-content" />
    <Glyph name="load" size={48} color={colors.grip} />
    <Copy size="heading" color={colors.paper}>{status === 'error' ? 'Journal unavailable' : 'Opening your journal'}</Copy>
    {status === 'error' && <>
      <Copy color={colors.paper} style={{textAlign: 'center'}}>{issue ?? 'Unlock your iPhone and try opening your journal again.'}</Copy>
      <Action title="Try again" icon="load" action={() => {void library.load();}} />
    </>}
  </View>;
}

const styles = StyleSheet.create({
  startup: {flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.ink, padding: 24, gap: 13},
});
