import React, {useEffect, useRef, useState} from 'react';
import {Keyboard, ScrollView, StyleSheet, View} from 'react-native';
import {errorText, useFlow} from '../navigation';
import {canContact, follows, library, useSkater, visibleActivity, visibleSkater} from '../state/library';
import {dateOf, isReported} from '../state/model';
import type {ChatMessage, ID} from '../state/model';
import {useMutation} from '../ui/mutation';
import {Action, Choices, colors, Copy, Empty, Field, IconAction, layout, Notice, Row, Screen} from '../ui/paper';
import {Avatar, Person} from './Crew';

const sections = ['Chats', 'Drafts', 'Activity'] as const;
const preview = (body: string) => Array.from(body).slice(0, 90).join('');

export function Messages({root = false}: {root?: boolean}) {
  const flow = useFlow();
  const {archive, account} = useSkater();
  const [section, select] = useState<(typeof sections)[number]>('Chats');
  const {busy, run} = useMutation();
  const drafts = [...account.drafts].sort((a, b) => b.savedAt - a.savedAt).flatMap(draft => {
    const peer = visibleSkater(archive, account, draft.peer);
    return peer && !isReported(account, {kind: 'conversation', id: draft.peer}) ? [{draft, peer}] : [];
  });
  const latest = new Map<ID, ChatMessage>();
  for (const message of archive.messages) {
    if (message.sender !== account.id && message.recipient !== account.id) continue;
    const peer = message.sender === account.id ? message.recipient : message.sender;
    if (!latest.has(peer) || latest.get(peer)!.date <= message.date) latest.set(peer, message);
  }
  const threads = [...latest].flatMap(([id, message]) => {
    const peer = visibleSkater(archive, account, id);
    return peer && !isReported(account, {kind: 'conversation', id}) ? [{peer, message}] : [];
  }).sort((a, b) => b.message.date - a.message.date);
  const activity = visibleActivity(archive, account);
  const unread = activity.filter(item => !item.read).length;
  return <Screen title="Inbox" ground="CrewGround" root={root}
    action={<IconAction title="Find a skater to chat with" icon="add" fill={colors.grip} action={() => flow.select('crew')} />}>
    <Copy>Conversations, saved drafts and your skate updates.</Copy>
    <Choices values={sections} value={section} onChange={select}
      label={value => value === 'Activity' && unread ? `Activity (${unread})` : value} />
    {section === 'Chats' ? <>
      {!threads.length ? <>
        <Empty icon="comment" title="Start with your crew" note="Open a skater’s profile to start a conversation." />
        <Action title="Explore Crew" icon="crew" action={() => flow.select('crew')} />
      </> : null}
      {threads.map(({peer, message}) => {
        const unreadThread = activity.some(event => event.kind === 'message' && event.actor === peer.id && !event.read);
        const body = (message.sender === account.id ? 'You: ' : '') + preview(message.body);
        return <Row key={peer.id} title={peer.profile.name} detail={(unreadThread ? 'Unread · ' : '') + body}
          action={() => flow.open({name: 'conversation', id: peer.id})}>
          <Avatar person={peer} size={48} />
        </Row>;
      })}
    </> : section === 'Drafts' ? <>
      {!drafts.length ? <Empty icon="comment" title="No saved drafts" note="Save a message when you want to finish it later." /> : null}
      {drafts.map(({draft, peer}) => <Row key={draft.id} title={peer.profile.name} detail={preview(draft.body)}
        action={() => flow.open({name: 'conversation', id: peer.id})}><Avatar person={peer} size={48} /></Row>)}
    </> : <>
      {unread ? <Action title="Mark activity read" icon="check" tone="paper" disabled={busy}
        action={() => {void run(() => library.markRead());}} /> : null}
      {!activity.length ? <Empty icon="comment" title="No activity yet" note="Messages and updates from your profile and submissions will appear here." /> : null}
      {activity.map(event => {
        if (event.kind === 'submission') return <Row key={event.id} title="Saved for review" detail={event.detail} icon="deck"
          action={() => flow.open({name: 'submissions'})} />;
        if (event.kind === 'report') return <Notice key={event.id}>{event.detail}</Notice>;
        const actor = event.actor && visibleSkater(archive, account, event.actor);
        if (!actor) return null;
        return event.kind === 'message' ? <Row key={event.id} title={`Message from ${actor.profile.name}`}
          detail={(event.read ? '' : 'Unread · ') + preview(event.detail)} icon="comment"
          action={() => flow.open({name: 'conversation', id: actor.id})} /> :
          <Row key={event.id} title={actor.profile.name + ' followed you'} detail={event.read ? undefined : 'Unread'} icon="crew"
            action={() => flow.open({name: 'profile', id: actor.id})} />;
      })}
    </>}
  </Screen>;
}

export function Conversation({id}: {id: ID}) {
  const flow = useFlow();
  const {archive, account} = useSkater();
  const saved = account.drafts.find(draft => draft.peer === id);
  const [draft, edit] = useState(saved?.body ?? '');
  const [removing, setRemoving] = useState<ID>();
  const [shown, setShown] = useState(50);
  const [showSafety, setShowSafety] = useState(false);
  const scroll = useRef<ScrollView>(null);
  const scrollToLatest = useRef(true);
  const {busy, run} = useMutation();
  const peer = visibleSkater(archive, account, id);
  const contact = canContact(archive, account, id);
  const available = Boolean(peer && !isReported(account, {kind: 'conversation', id}));
  const messages = archive.messages.filter(message =>
    (message.sender === account.id && message.recipient === id) || (message.sender === id && message.recipient === account.id))
    .sort((a, b) => a.date - b.date);
  const unread = visibleActivity(archive, account).filter(event => event.kind === 'message' && event.actor === id && !event.read).length;
  useEffect(() => {
    if (flow.visible && available && unread) {
      void library.markConversationRead(id).catch(error => flow.notice(errorText(error)));
    }
  }, [flow.visible, available, id, unread]);

  function call(video: boolean) {
    const latest = library.snapshot();
    const viewer = latest.activeID && latest.archive.accounts[latest.activeID];
    if (!viewer || !canContact(latest.archive, viewer, id)) {
      flow.notice('Both skaters must follow each other before call waiting can open.');
      return;
    }
    flow.open({name: 'call', id, video});
  }

  function send() {
    scrollToLatest.current = true;
    void run(() => library.sendMessage(id, draft), () => {edit(''); Keyboard.dismiss();});
  }

  return <Screen title={peer?.profile.name ?? 'Chat'} ground="CrewGround" editing scrollRef={scroll}
    action={<IconAction title="Conversation actions" icon="more" fill={colors.paper} action={() => setShowSafety(value => !value)} />}
    onContentSizeChange={() => {
      if (flow.visible && scrollToLatest.current) {
        scroll.current?.scrollToEnd({animated: false});
        scrollToLatest.current = false;
      }
    }}>
    {peer && available ? <>
      <Person person={peer} detail="Open skate profile" />
      {showSafety ? <View style={layout.stack}>
        <Row title="Report chat" icon="flag" action={() => flow.open({name: 'report', subject: {kind: 'conversation', id}})} />
        <Row title="Block skater" icon="close" action={() => flow.open({name: 'block', id})} />
      </View> : null}
      <View style={layout.row}>
        <Action title="Voice" icon="phone" tone="paper" action={() => call(false)} />
        <Action title="Video" icon="video" tone="paper" action={() => call(true)} />
      </View>
      {!contact ? <>
        <Notice>Follow each other before sending messages or opening call waiting.</Notice>
        {!follows(archive, account, id) && <Action title={`Follow ${peer.profile.name}`} icon="crew" disabled={busy}
          action={() => {void run(() => library.toggleFollow(id));}} />}
      </> : null}
      {messages.length > shown ? <Action title="Earlier messages" icon="load" tone="paper"
        action={() => {scrollToLatest.current = false; setShown(value => value + 50);}} /> : null}
      {!messages.length ? <Empty icon="comment" title="Your conversation starts here" note="Say something about the next session." /> : null}
      {messages.slice(-shown).map(message => {
        const own = message.sender === account.id;
        return <View key={message.id} style={[styles.bubble, own ? styles.outgoing : styles.incoming]}>
          <Copy color={own ? colors.paper : colors.ink}>{message.body}</Copy>
          <View style={styles.messageMeta}>
            <Copy size="caption" color={own ? colors.sage : colors.muted}>
              {dateOf(message.date).toLocaleString('en', {month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'})}
            </Copy>
            {own ? <IconAction title="Delete your message" icon="close" color={colors.paper} action={() => setRemoving(message.id)} /> : null}
          </View>
        </View>;
      })}
      {removing ? <View style={layout.section}>
        <Copy>Delete this message from the conversation?</Copy>
        <View style={layout.row}>
          <Action title="Delete message" tone="danger" disabled={busy} action={() => {
            void run(() => library.removeMessage(removing), () => setRemoving(undefined));
          }} />
          <Action title="Keep message" tone="paper" action={() => setRemoving(undefined)} />
        </View>
      </View> : null}
      <Field label="Message" value={draft} onChangeText={edit} multiline maxLength={600} />
      <View style={layout.row}>
        <Action title={busy ? 'Saving…' : 'Send message'} icon="send" disabled={busy || !draft.trim() || !contact} action={send} />
        <Action title="Save draft" tone="paper" disabled={busy || !draft.trim() || !contact}
          action={() => {void run(() => library.saveDraft(id, draft), () => {Keyboard.dismiss(); flow.notice('Draft saved.');});}} />
      </View>
      {saved ? <Action title="Discard saved draft" icon="close" tone="plain" disabled={busy}
        action={() => {void run(() => library.removeDraft(id), () => {edit(''); flow.notice('Draft discarded.');});}} /> : null}
    </> : <Empty icon="comment" title="Chat unavailable" />}
  </Screen>;
}

const styles = StyleSheet.create({
  bubble: {maxWidth: '88%', borderRadius: 17, paddingHorizontal: 15, paddingTop: 13, paddingBottom: 5, gap: 3},
  outgoing: {alignSelf: 'flex-end', backgroundColor: colors.ink},
  incoming: {alignSelf: 'flex-start', backgroundColor: colors.sage},
  messageMeta: {flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 9},
});
