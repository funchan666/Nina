import React, {useEffect, useRef, useState} from 'react';
import {Linking, View} from 'react-native';
import {attachmentURI, platform} from '../native';
import type {PickSource} from '../native';
import {errorText, useFlow} from '../navigation';
import {library} from '../state/library';
import type {Attachment, ID} from '../state/model';
import {Poster} from './media';
import {Action, layout, Notice} from './paper';

export function useAttachment(owner: ID, avatar = false) {
  const flow = useFlow();
  const mounted = useRef(false);
  const choosing = useRef(false);
  const staged = useRef<Attachment | undefined>(undefined);
  const [selection, setSelection] = useState<Attachment>();
  const [busy, setBusy] = useState(false);
  const [permissionIssue, setPermissionIssue] = useState(false);

  function discard(attachment?: Attachment) {
    if (attachment) {
      void library.removeAttachment(owner, attachment).catch(() => {});
    }
  }

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      discard(staged.current);
      staged.current = undefined;
    };
  }, [owner]);

  async function choose(source: PickSource) {
    if (choosing.current) {
      return;
    }
    choosing.current = true;
    setBusy(true);
    setPermissionIssue(false);
    try {
      const result = await platform('pick', {source, owner, avatar});
      if (!result) {
        return;
      }
      if (!mounted.current) {
        discard(result);
        return;
      }
      discard(staged.current);
      staged.current = result;
      setSelection(result);
      flow.notice('');
    } catch (error) {
      if (mounted.current) {
        const message = errorText(error);
        setPermissionIssue(message.includes('Settings'));
        flow.notice(message);
      }
    } finally {
      choosing.current = false;
      if (mounted.current) {
        setBusy(false);
      }
    }
  }

  function clear() {
    discard(staged.current);
    staged.current = undefined;
    setSelection(undefined);
  }

  async function commit(save: (selected?: Attachment) => Promise<unknown>) {
    const item = staged.current;
    staged.current = undefined;
    try {
      await save(item);
    } catch (error) {
      if (mounted.current) {
        staged.current = item;
      } else {
        discard(item);
      }
      throw error;
    }
  }
  return {selection, busy, permissionIssue, choose, clear, commit};
}

export function AttachmentSources({avatar, disabled, permissionIssue, choose}: {
  avatar?: boolean; disabled?: boolean; permissionIssue?: boolean; choose(source: PickSource): Promise<void>;
}) {
  return <View style={layout.stack}>
    <Action title={avatar ? 'Choose a profile photo' : 'Choose photo or film'} icon={avatar ? 'avatar' : 'deck'}
      disabled={disabled} tone="paper" action={() => {void choose('photos');}} />
    <Action title={avatar ? 'Take a profile photo' : 'Take a photo'} icon="camera"
      disabled={disabled} tone="paper" action={() => {void choose('picture');}} />
    {!avatar && <Action title="Record a film" icon="video" disabled={disabled} tone="paper" action={() => {void choose('movie');}} />}
    {permissionIssue && <Action title="Open iPhone Settings" icon="settings" tone="paper"
      action={() => {void Linking.openSettings().catch(() => {});}} />}
  </View>;
}

export function AttachmentPreview({root, owner, media, avatar}: {
  root: string; owner: ID; media: Attachment; avatar?: boolean;
}) {
  const file = media.type === 'video' ? media.posterFile : media.file;
  const uri = attachmentURI(root, owner, file);
  return uri ? <View style={{height: avatar ? 132 : 185}}>
    <Poster uri={uri} label={media.type === 'video' ? 'Selected film' : 'Selected photo'} contain />
  </View> : <Notice>{media.type === 'video' ? 'Film selected' : 'Photo selected'}</Notice>;
}
