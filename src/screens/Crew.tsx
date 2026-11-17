import React, {useState} from 'react';
import {StyleSheet, View} from 'react-native';
import {attachmentURI} from '../native';
import {useFlow} from '../navigation';
import {
  follows, library, relationships, sharedAttempts, useSkater, visibleActivity, visibleSkater,
} from '../state/library';
import {balance, dateOf, findLine, isReported, lines, progress, stances, titleCase} from '../state/model';
import type {Account, ID, Stance} from '../state/model';
import {AttachmentPreview, AttachmentSources, useAttachment} from '../ui/attachment';
import {Poster} from '../ui/media';
import {useMutation} from '../ui/mutation';
import {Action, Choices, colors, Copy, Empty, Field, Glyph, IconAction, layout, Notice, Row, Screen} from '../ui/paper';

export function Crew({spotKey, title}: {spotKey?: string; title?: string}) {
  const flow = useFlow();
  const {archive, account} = useSkater();
  const [query, setQuery] = useState('');
  const unread = visibleActivity(archive, account).filter(item => !item.read).length;
  const crew = Object.values(archive.accounts).filter(member => member.id !== account.id &&
    visibleSkater(archive, account, member.id) &&
    (!spotKey || sharedAttempts(member, spotKey).length > 0));
  const matching = crew.filter(member => member.profile.name.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase()))
    .sort((a, b) => a.profile.name.localeCompare(b.profile.name));
  return <Screen title={title ?? 'Crew'} ground="CrewGround" root={!spotKey} editing
    action={!spotKey ? <Action title={unread ? `Messages (${unread})` : 'Messages'} icon="comment"
      action={() => flow.open({name: 'messages'})} /> : undefined}>
    {!spotKey ? <>
      <Row title="Your skate profile" detail={account.profile.name} icon="avatar"
        action={() => flow.open({name: 'profile', id: account.id})} />
      <Copy size="heading" header>Find skaters</Copy>
    </> : <Copy color={colors.muted}>Skaters with shared sessions here.</Copy>}
    {crew.length ? <Field label="Find by name" value={query} onChangeText={setQuery} /> : null}
    {!matching.length ? <Empty title={spotKey ? 'No shared sessions here' : 'No other skaters here yet'} icon="crew"
      note={query.trim() ? 'Try a different name.' : 'Shared sessions connect skaters through a spot.'} /> : null}
    {matching.map(member => {
      const sessions = sharedAttempts(member, spotKey);
      return <Person key={member.id} person={member} detail={sessions.length
        ? `${titleCase(member.profile.stance)} · ${sessions.length} shared ${sessions.length === 1 ? 'session' : 'sessions'}`
        : undefined} />;
    })}
  </Screen>;
}

function Avatar({person, size}: {person: Account; size: number}) {
  const {config} = useSkater();
  const uri = attachmentURI(config.fileBase, person.id, person.profile.avatar?.file);
  return <View accessible={false} accessibilityElementsHidden style={[styles.avatar, {width: size, height: size}]}>
    {uri ? <Poster uri={uri} label="Profile photo" /> :
      <View style={styles.defaultAvatar}><Glyph name="avatar" size={size * 0.65} /></View>}
  </View>;
}

export function Person({person, detail}: {person: Account; detail?: string}) {
  const flow = useFlow();
  return <Row title={person.profile.name} detail={detail ?? titleCase(person.profile.stance)}
    action={() => flow.open({name: 'profile', id: person.id})}>
    <Avatar person={person} size={48} />
  </Row>;
}

export function ProfileDetails({id}: {id: ID}) {
  const flow = useFlow();
  const {archive, account} = useSkater();
  const {busy, run} = useMutation();
  const [more, setMore] = useState(false);
  const profile = visibleSkater(archive, account, id);
  const own = id === account.id;
  const outgoing = relationships(archive, account, id, false);
  const incoming = relationships(archive, account, id, true);
  return <Screen title={profile?.profile.name ?? 'Skater'} ground="CrewGround"
    action={own ? <Action title="Edit" icon="edit" action={() => flow.open({name: 'profileEditor'})} /> : undefined}>
    {profile ? <>
      <View style={layout.section}>
        <View style={styles.profile}>
          <Avatar person={profile} size={80} />
          <View style={layout.fill}>
            <Copy size="card">{titleCase(profile.profile.stance)} stance</Copy>
            {profile.profile.bio ? <Copy>{profile.profile.bio}</Copy> : null}
          </View>
        </View>
        <View style={layout.row}>
          <Action title={`Followers (${incoming.length})`} icon="crew" tone="paper"
            action={() => flow.open({name: 'relationships', id, incoming: true})} />
          <Action title={`Following (${outgoing.length})`} tone="paper"
            action={() => flow.open({name: 'relationships', id, incoming: false})} />
        </View>
      </View>
      {own ? <SkateRecord person={profile} /> : <>
        <View style={layout.row}>
          <Action title={follows(archive, account, id) ? 'Unfollow' : 'Follow'} icon="crew" disabled={busy}
            action={() => {void run(() => library.toggleFollow(id));}} />
          <Action title="Chat" icon="comment" tone="paper" action={() => flow.open({name: 'conversation', id})} />
          <IconAction title="More profile actions" icon="more" fill={colors.paper} action={() => setMore(value => !value)} />
        </View>
        {more && <View style={layout.stack}>
          <Row title="Report profile" icon="flag" action={() => flow.open({name: 'report', subject: {kind: 'skater', id}})} />
          <Row title={`Block ${profile.profile.name}`} icon="close" action={() => flow.open({name: 'block', id})} />
        </View>}
        <SharedWork person={profile} />
      </>}
    </> : <Empty icon="avatar" title="Profile unavailable" />}
  </Screen>;
}

function SkateRecord({person}: {person: Account}) {
  const flow = useFlow();
  const visits = person.attempts.filter(attempt => attempt.attempts > 0).length;
  const saved = lines.filter(line => person.saved.includes(line.id) && !isReported(person, {kind: 'line', id: line.id}));
  return <>
    <Copy size="heading" header>Skate record</Copy>
    <Notice>{person.spots.length} saved {person.spots.length === 1 ? 'spot' : 'spots'} · {visits} logged {visits === 1 ? 'session' : 'sessions'}</Notice>
    <Row title="Open your sessions" icon="sessions" action={() => flow.select('sessions')} />
    <Row title="Your submissions" detail={`${person.submissions.length} awaiting review`} icon="deck"
      action={() => flow.open({name: 'submissions'})} />
    <Row title="Wallet" detail={`${balance(person)} Grip`} icon="grip" action={() => flow.open({name: 'wallet'})} />
    <Row title="Settings" icon="settings" action={() => flow.open({name: 'settings'})} />
    <Copy size="heading" header>Saved lines</Copy>
    {!saved.length ? <Notice>Save a line to return to it later.</Notice> : null}
    {saved.map(line => <Row key={line.id} title={line.title} icon="saved" action={() => flow.open({name: 'line', id: line.id})} />)}
  </>;
}

function SharedWork({person}: {person: Account}) {
  const flow = useFlow();
  const {account} = useSkater();
  const sessions = sharedAttempts(person).sort((a, b) => b.date - a.date);
  return <View style={layout.stack}>
    <Copy size="heading" header>Shared sessions</Copy>
    {!sessions.length ? <Notice>This skater hasn’t shared a session.</Notice> : null}
    {sessions.map(attempt => {
      const spot = person.spots.find(item => item.id === attempt.spotID);
      const line = findLine(attempt.referenceID);
      return <View key={attempt.id} style={layout.section}>
        <Copy size="card">{attempt.trick}</Copy>
        <Copy>{[spot?.name, titleCase(attempt.stance), progress(attempt)].filter(Boolean).join(' · ')}</Copy>
        <Copy size="caption">{attempt.landings} landed / {attempt.attempts} tries</Copy>
        <Copy size="caption" color={colors.muted}>{dateOf(attempt.date).toLocaleDateString()}</Copy>
        {line && !isReported(account, {kind: 'line', id: line.id}) ?
          <Action title={line.title} icon="lines" tone="plain" action={() => flow.open({name: 'line', id: line.id})} /> : null}
      </View>;
    })}
  </View>;
}

export function Relationships({id, incoming}: {id: ID; incoming: boolean}) {
  const {archive, account} = useSkater();
  const items = visibleSkater(archive, account, id) ? relationships(archive, account, id, incoming) : [];
  return <Screen title={incoming ? 'Followers' : 'Following'} ground="CrewGround">
    {!items.length ? <Empty icon="crew" title="No skaters to show" /> : null}
    {items.map(member => <Person key={member.id} person={member} />)}
  </Screen>;
}

export function ProfileEditor() {
  const flow = useFlow();
  const {account, config} = useSkater();
  const original = account.profile;
  const [name, setName] = useState(original.name);
  const [bio, setBio] = useState(original.bio);
  const [stance, setStance] = useState<Stance>(original.stance);
  const [removeAvatar, setRemoveAvatar] = useState(false);
  const media = useAttachment(account.id, true);
  const {busy, run} = useMutation();

  function save() {
    void run(() => media.commit(async selected => {
      const avatar = selected ?? (removeAvatar ? undefined : original.avatar);
      await library.updateProfile({name, bio, stance, avatar});
      if (original.avatar && original.avatar.file !== avatar?.file) {
        await library.removeAttachment(account.id, original.avatar).catch(() => {});
      }
    }), () => {flow.back(); flow.notice('Profile saved.');});
  }

  return <Screen title="Edit profile" ground="CrewGround" editing>
    {media.selection ? <AttachmentPreview root={config.fileBase} owner={account.id} media={media.selection} avatar /> :
      !removeAvatar ? <Avatar person={account} size={83} /> : null}
    <AttachmentSources avatar choose={media.choose} disabled={busy || media.busy}
      permissionIssue={media.permissionIssue} />
    {(media.selection || (original.avatar && !removeAvatar)) && <Action title="Remove photo" icon="close" tone="paper"
      disabled={busy || media.busy} action={() => {media.clear(); setRemoveAvatar(true);}} />}
    {media.busy && <Notice>Opening profile media…</Notice>}
    <Field label="Display name" value={name} onChangeText={setName} editable={!busy} />
    <View style={layout.stack}>
      <Copy size="label">Stance</Copy>
      <Choices values={stances} value={stance} onChange={setStance} label={titleCase} />
    </View>
    <Field label="Skater bio" value={bio} onChangeText={setBio} multiline editable={!busy} />
    <Action title={busy ? 'Saving…' : 'Save profile'} icon="check" action={save} disabled={busy || media.busy || !name.trim()} />
  </Screen>;
}

const styles = StyleSheet.create({
  avatar: {backgroundColor: colors.grip, overflow: 'hidden'},
  defaultAvatar: {flex: 1, alignItems: 'center', justifyContent: 'center'},
  profile: {flexDirection: 'row', alignItems: 'flex-start', gap: 12},
});
