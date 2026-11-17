import React, {useRef, useState} from 'react';
import {Image, ScrollView, StyleSheet, View} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import {NativeSurface} from '../native';
import type {Policy} from '../native';
import {errorText} from '../navigation';
import {library, useJournal} from '../state/library';
import {wheelMark} from '../ui/artwork';
import {useWindowLayout} from '../ui/geometry';
import {Action, Backdrop, Check, colors, Copy, Glyph, layout, Notice} from '../ui/paper';
import {WebPageScreen} from '../ui/WebPage';

export function Welcome({onCommunity}: {onCommunity: () => void}) {
  const safe = useSafeAreaInsets();
  const {margins} = useWindowLayout();
  const {warning} = useJournal();
  const [policy, setPolicy] = useState<Policy>();
  const [accepted, accept] = useState(false);
  const lock = useRef(false);
  const [busy, setBusy] = useState(false);
  const [issue, setIssue] = useState('');
  async function enter() {
    if (!accepted || lock.current) {
      return;
    }
    lock.current = true;
    setIssue('');
    setBusy(true);
    try {
      await library.signInApple();
    } catch (error) {
      const message = errorText(error);
      if (message !== 'Apple sign-in canceled.') {
        setIssue(message);
      }
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }

  return <View style={styles.canvas}>
    <Backdrop image="WelcomeGround" />
    <Image source={wheelMark} accessible={false}
      style={[styles.mark, {top: safe.top + 6, left: safe.left + margins.left}]} />
    <ScrollView
      accessibilityElementsHidden={Boolean(policy)}
      keyboardShouldPersistTaps="handled" keyboardDismissMode="interactive"
      contentInsetAdjustmentBehavior="never"
      contentContainerStyle={{
        flexGrow: 1, justifyContent: 'flex-end', paddingTop: safe.top + 82, paddingBottom: safe.bottom + 10,
        paddingLeft: safe.left + margins.left, paddingRight: safe.right + margins.right,
      }}
    >
      <View style={styles.form}>
        <View>
          <Copy size="title" header color={colors.paper}>Nina</Copy>
        </View>
        <View style={styles.terms}>
          <Check title="I agree to the Terms and Privacy Policy" value={accepted} toggle={() => {
            if (!busy) {accept(value => !value);}
          }} />
          <View style={layout.row}>
            <Action title="Terms" tone="paper" disabled={busy} action={() => setPolicy('terms')} />
            <Action title="Privacy" tone="paper" disabled={busy} action={() => setPolicy('privacy')} />
          </View>
        </View>
        {busy && <View style={layout.row}>
          <Glyph name="load" color={colors.grip} />
          <Copy size="label" color={colors.paper}>Opening your profile</Copy>
        </View>}
        {warning ? <Notice>{warning}</Notice> : null}
        {issue ? <Notice error>{issue}</Notice> : null}
        <NativeSurface kind="apple" enabled={accepted && !busy} style={[styles.apple, !accepted && styles.appleLocked]}
          onSignal={({nativeEvent}) => {if (nativeEvent.status === 'pressed') {void enter();}}} />
        <Action title="Back to community" tone="paper" icon="back" action={onCommunity} disabled={busy} />
      </View>
    </ScrollView>
    {policy ? <View style={StyleSheet.absoluteFill} accessibilityViewIsModal>
      <WebPageScreen key={policy} page={policy} close={() => setPolicy(undefined)} />
    </View> : null}
  </View>;
}

export function OpeningJournal() {
  const {status, issue} = useJournal();
  return <View style={styles.startup}>
    <Image source={wheelMark} accessible={false} style={{width: 122, height: 122}} />
    <Copy size="heading" color={colors.paper}>{status === 'error' ? 'Journal unavailable' : 'Opening Nina'}</Copy>
    {status === 'error' && <>
      <Copy color={colors.paper} style={{textAlign: 'center'}}>{issue ?? 'Unlock your iPhone and try opening your journal again.'}</Copy>
      <Action title="Try again" icon="load" action={() => {void library.load();}} />
    </>}
  </View>;
}

const styles = StyleSheet.create({
  canvas: {flex: 1, backgroundColor: colors.ink},
  mark: {position: 'absolute', width: 68, height: 68},
  form: {width: '100%', maxWidth: 460, alignSelf: 'center', backgroundColor: 'rgba(24,38,32,0.97)', padding: 16, gap: 10},
  terms: {backgroundColor: colors.sage, paddingHorizontal: 8, paddingBottom: 6},
  apple: {height: 47, width: '100%'},
  appleLocked: {opacity: 0.48},
  startup: {flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.ink, padding: 24, gap: 13},
});
