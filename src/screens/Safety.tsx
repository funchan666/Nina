import React, {useState} from 'react';
import {Linking, StyleSheet, View} from 'react-native';
import {errorText, useFlow} from '../navigation';
import {library, useSkater, visibleSkater} from '../state/library';
import {reasons} from '../state/model';
import type {ID, Subject} from '../state/model';
import {useMutation} from '../ui/mutation';
import {Action, Check, colors, Copy, Empty, layout, Notice, Row, Screen} from '../ui/paper';
import {webPageTitles} from '../ui/WebPage';

export function Report({subject}: {subject: Subject}) {
  const flow = useFlow();
  const [reason, select] = useState<string>();
  const {busy, run} = useMutation();
  return <Screen title="Report" ground="CrewGround">
    <Copy>Choose why you want to hide this item.</Copy>
    {reasons.map(option => <Action key={option} title={option} icon={reason === option ? 'check' : undefined}
      selected={reason === option} tone={reason === option ? 'ink' : 'paper'} action={() => select(option)} />)}
    {reason && <>
      <Notice>Confirm this report to hide the item.</Notice>
      <Action title="Confirm report" icon="flag" tone="danger" disabled={busy} action={() => {
        void run(() => library.report(subject, reason), () => {flow.back(); flow.notice('Report recorded. Item hidden.');});
      }} />
    </>}
  </Screen>;
}

export function Block({id}: {id: ID}) {
  const flow = useFlow();
  const {account, archive} = useSkater();
  const {busy, run} = useMutation();
  const person = visibleSkater(archive, account, id)?.profile.name ?? 'this skater';
  return <Screen title="Block skater" ground="CrewGround">
    <Empty icon="flag" title={`Block ${person}?`} note="Blocking hides profiles, comments and activity and removes both follow connections." />
    <Action title="Block skater" icon="close" tone="danger" disabled={busy} action={() => {
      void run(() => library.block(id, true), () => {flow.back(); flow.notice('Skater blocked.');});
    }} />
    <Action title="Cancel" tone="paper" action={flow.back} />
  </Screen>;
}

export function Blacklist() {
  const flow = useFlow();
  const {account, archive} = useSkater();
  const {busy, run} = useMutation();
  const people = account.blocked.map(id => archive.accounts[id]).filter(Boolean)
    .sort((a, b) => a.profile.name.localeCompare(b.profile.name));
  return <Screen title="Blocked skaters" ground="CrewGround">
    {!people.length ? <Empty icon="crew" title="No blocked skaters" /> : null}
    {people.map(person => <View key={person.id} style={layout.section}>
      <Copy size="card">{person.profile.name}</Copy>
      <Action title="Unblock" icon="check" tone="paper" disabled={busy} action={() => {
        void run(() => library.block(person.id, false), () => flow.notice('Skater unblocked.'));
      }} />
    </View>)}
  </Screen>;
}

export function Settings() {
  const flow = useFlow();
  const {config} = useSkater();
  const {busy, run} = useMutation();
  const pages = ['website', 'terms', 'privacy'] as const;
  return <Screen title="Settings" ground="CrewGround">
    <SettingsGroup title="About Nina">
      {pages.map(page => <Row key={page} title={webPageTitles[page]}
        action={() => flow.open({name: 'webPage', page})} />)}
      {config.supportEmail ? <Row title="Contact support" icon="comment" action={() => {
        void Linking.openURL(`mailto:${config.supportEmail}`).catch(error => flow.notice(errorText(error)));
      }} /> : null}
    </SettingsGroup>
    <SettingsGroup title="Crew safety">
      <Row title={webPageTitles.rules} action={() => flow.open({name: 'webPage', page: 'rules'})} />
      <Row title="Blocked skaters" action={() => flow.open({name: 'blacklist'})} />
    </SettingsGroup>
    <SettingsGroup title="Profile">
      <Row title={busy ? 'Signing out…' : 'Sign out'} disabled={busy} action={() => {void run(() => library.signOut());}} />
      <Row title="Delete profile" disabled={busy} action={() => flow.open({name: 'deleteProfile'})} />
    </SettingsGroup>
  </Screen>;
}

function SettingsGroup({title, children}: {title: string; children: React.ReactNode}) {
  return <View style={styles.settingsGroup}>
    <Copy size="label" header style={styles.settingsHeading}>{title}</Copy>
    {children}
  </View>;
}

export function DeleteProfile() {
  const [confirmed, check] = useState(false);
  const {busy, run} = useMutation();
  return <Screen title="Delete profile" ground="CrewGround">
    <Empty icon="avatar" title="Remove your skate profile"
      note="This erases your spots, trick logs, media, drafts, connections and Grip from Nina on this iPhone." />
    <Check title="Delete this profile and its records" value={confirmed} toggle={() => check(value => !value)} />
    <Action title={busy ? 'Deleting profile…' : 'Delete profile'} icon="close" tone="danger" disabled={!confirmed || busy}
      action={() => {void run(() => library.deleteAccount());}} />
  </Screen>;
}

const styles = StyleSheet.create({
  settingsGroup: {backgroundColor: colors.sage, gap: StyleSheet.hairlineWidth},
  settingsHeading: {paddingHorizontal: 10, paddingVertical: 9},
});
