import React, {useState} from 'react';
import {Keyboard, View} from 'react-native';
import {useFlow} from '../navigation';
import {canContact, follows, library, useSkater, visibleActivity, visibleSkater} from '../state/library';
import {isReported} from '../state/model';
import type {ID} from '../state/model';
import {useMutation} from '../ui/mutation';
import {Action, Choices, Empty, Field, layout, Notice, Row, Screen} from '../ui/paper';
import {Person} from './Crew';

const sections = ['Drafts', 'Activity'] as const;

export function Messages() {
  const flow = useFlow();
  const {archive, account} = useSkater();
  const [section, select] = useState<(typeof sections)[number]>('Drafts');
  const {busy, run} = useMutation();
  const drafts = [...account.drafts].sort((a, b) => b.savedAt - a.savedAt).flatMap(draft => {
    const peer = visibleSkater(archive, account, draft.peer);
    return peer && !isReported(account, {kind: 'conversation', id: draft.peer}) ? [{draft, peer}] : [];
  });
  const activity = visibleActivity(archive, account);
  const unread = activity.filter(item => !item.read).length;
  return <Screen title="Messages" ground="CrewGround">
    <Choices values={sections} value={section} onChange={select}
      label={value => value === 'Activity' && unread ? `Activity (${unread})` : value} />
    {section === 'Drafts' ? <>
      {!drafts.length ? <Empty icon="comment" title="No message drafts" note="Open a skater’s profile to find their chat." /> : null}
      {drafts.map(({draft, peer}) => <Row key={draft.id} title={peer.profile.name} detail={draft.body} icon="comment"
        action={() => flow.open({name: 'conversation', id: peer.id})} />)}
    </> : <>
      {unread ? <Action title="Mark activity read" icon="check" tone="paper" disabled={busy}
        action={() => {void run(() => library.markRead());}} /> : null}
      {!activity.length ? <Empty icon="comment" title="No activity" note="Updates from your profile and submissions will appear here." /> : null}
      {activity.map(event => {
        if (event.kind === 'submission') {
          return <Row key={event.id} title="Saved for review" detail={event.detail} icon="deck"
            action={() => flow.open({name: 'submissions'})} />;
        }
        if (event.kind === 'report') {
          return <Notice key={event.id}>{event.detail}</Notice>;
        }
        const actor = event.actor && visibleSkater(archive, account, event.actor);
        return actor ? <Row key={event.id} title={actor.profile.name + ' followed you'}
          detail={event.read ? undefined : 'Unread'} icon="crew"
          action={() => flow.open({name: 'profile', id: actor.id})} /> : null;
      })}
    </>}
  </Screen>;
}

export function Conversation({id}: {id: ID}) {
  const flow = useFlow();
  const {archive, account} = useSkater();
  const saved = account.drafts.find(draft => draft.peer === id);
  const [draft, edit] = useState(saved?.body ?? '');
  const {busy, run} = useMutation();
  const peer = visibleSkater(archive, account, id);
  const contact = canContact(archive, account, id);

  function call(video: boolean) {
    const latest = library.snapshot();
    const viewer = latest.activeID && latest.archive.accounts[latest.activeID];
    if (!viewer || !canContact(latest.archive, viewer, id)) {
      flow.notice('Both skaters must follow each other before call waiting can open.');
      return;
    }
    flow.open({name: 'call', id, video});
  }

  return <Screen title={peer?.profile.name ?? 'Chat'} ground="CrewGround" editing>
    {peer && !isReported(account, {kind: 'conversation', id}) ? <>
      <Person person={peer} detail="Open skate profile" />
      <View style={layout.row}>
        <Action title="Voice" icon="phone" tone="paper" action={() => call(false)} />
        <Action title="Video" icon="video" tone="paper" action={() => call(true)} />
      </View>
      {!contact ? <>
        <Notice>Both skaters must follow each other to save a draft or open call waiting.</Notice>
        {!follows(archive, account, id) && <Action title={`Follow ${peer.profile.name}`} icon="crew" disabled={busy}
          action={() => {void run(() => library.toggleFollow(id));}} />}
      </> : null}
      <Field label="Message draft" value={draft} onChangeText={edit} multiline />
      <Action title="Save draft" icon="send" disabled={busy || !draft.trim()}
        action={() => {void run(() => library.saveDraft(id, draft), () => {Keyboard.dismiss(); flow.notice('Draft saved.');});}} />
      {saved ? <Action title="Discard saved draft" icon="close" tone="paper" disabled={busy}
        action={() => {void run(() => library.removeDraft(id), () => {edit(''); flow.notice('Draft discarded.');});}} /> : null}
      <Row title="Report chat" icon="flag" action={() => flow.open({name: 'report', subject: {kind: 'conversation', id}})} />
      <Row title="Block skater" icon="close" action={() => flow.open({name: 'block', id})} />
    </> : <Empty icon="comment" title="Chat unavailable" />}
  </Screen>;
}
