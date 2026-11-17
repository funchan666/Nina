import React, {useState} from 'react';
import {View} from 'react-native';
import {attachmentURI} from '../native';
import {useFlow} from '../navigation';
import {library, useSkater} from '../state/library';
import {now, recordID} from '../state/model';
import type {ID} from '../state/model';
import {AttachmentPreview, AttachmentSources, useAttachment} from '../ui/attachment';
import {Film, MediaStage, Poster} from '../ui/media';
import {useMutation} from '../ui/mutation';
import {Action, colors, Copy, Empty, Field, layout, Notice, Screen} from '../ui/paper';

export function PostEditor({id}: {id?: ID}) {
  const flow = useFlow();
  const {account, config} = useSkater();
  const original = account.submissions.find(post => post.id === id);
  const [title, setTitle] = useState(original?.title ?? '');
  const [caption, setCaption] = useState(original?.caption ?? '');
  const [confirmDelete, setConfirmDelete] = useState(false);
  const media = useAttachment(account.id);
  const {busy, run} = useMutation();
  function save() {
    void run(() => media.commit(async selected => {
      const attachment = selected ?? original?.attachment;
      if (!attachment) {
        throw new Error('Choose a photo or film.');
      }
      await library.saveSubmission({
        id: original?.id ?? recordID(), title, caption, attachment,
        status: 'Awaiting review', createdAt: original?.createdAt ?? now(),
      });
      if (original && selected) {
        await library.removeAttachment(account.id, original.attachment).catch(() => {});
      }
    }), () => {
      flow.back();
      flow.notice('Saved for review.');
    });
  }
  return <Screen title={id ? 'Edit submission' : 'Post a line'} ground="LinesGround" editing>
    {!id || original ? <>
      <Field label="Title" value={title} onChangeText={setTitle} editable={!busy} />
      <Field label="Caption" value={caption} onChangeText={setCaption} multiline editable={!busy} />
      <View style={layout.stack}>
        <Copy size="heading" header>Skate media</Copy>
        {media.selection ? <>
          <AttachmentPreview root={config.fileBase} owner={account.id} media={media.selection} />
          <Action title="Clear selection" icon="close" tone="paper" action={media.clear} disabled={busy || media.busy} />
        </> : original && <Action title="View attached media" icon="expand" tone="paper"
          action={() => flow.open({name: 'submissionViewer', id: original.id})} />}
        <AttachmentSources choose={media.choose} disabled={busy || media.busy} permissionIssue={media.permissionIssue} />
        {media.busy && <Notice>Opening skate media…</Notice>}
      </View>
      <Notice>Only you can view items in your review queue.</Notice>
      <Action title={busy ? 'Saving…' : 'Save for review'} icon="check" action={save}
        disabled={busy || media.busy || !title.trim() || (!media.selection && !original)} />
      {id ? (confirmDelete ? <View style={layout.stack}>
        <Notice>Remove this submission and its media?</Notice>
        <Action title="Remove submission" tone="danger" disabled={busy || media.busy}
          action={() => {void run(() => library.removeSubmission(id), () => {flow.back(); flow.notice('Submission removed.');});}} />
        <Action title="Keep submission" tone="paper" action={() => setConfirmDelete(false)} />
      </View> : <Action title="Remove submission" tone="paper" disabled={busy || media.busy} action={() => setConfirmDelete(true)} />) : null}
    </> : <Notice error>This submission is unavailable.</Notice>}
  </Screen>;
}

export function Submissions() {
  const flow = useFlow();
  const {account} = useSkater();
  return <Screen title="Submissions" ground="LinesGround"
    action={<Action title="Post" icon="add" action={() => flow.open({name: 'post'})} />}>
    {!account.submissions.length && <Empty icon="deck" title="No submissions" note="Save your first photo or film for review." />}
    {account.submissions.map(post => <View key={post.id} style={layout.section}>
      <Copy size="caption" color={colors.muted}>{post.status}</Copy>
      <Copy size="card">{post.title}</Copy>
      {post.caption ? <Copy>{post.caption}</Copy> : null}
      <View style={layout.row}>
        <Action title="View media" icon="expand" tone="ink" action={() => flow.open({name: 'submissionViewer', id: post.id})} />
        <Action title="Edit" icon="edit" tone="plain" action={() => flow.open({name: 'post', id: post.id})} />
      </View>
    </View>)}
  </Screen>;
}

export function SubmissionViewer({id}: {id: ID}) {
  const {account, config} = useSkater();
  const post = account.submissions.find(item => item.id === id);
  return <MediaStage title={post?.title ?? 'Submission'}>
    {post ? post.attachment.type === 'video' ? <Film id={post.attachment.file} title={post.title}
      uri={attachmentURI(config.fileBase, account.id, post.attachment.file)}
      poster={attachmentURI(config.fileBase, account.id, post.attachment.posterFile)} fullscreen /> :
      <Poster uri={attachmentURI(config.fileBase, account.id, post.attachment.file)} label={post.title} contain /> :
      <Empty title="Submission unavailable" icon="deck" />}
  </MediaStage>;
}
