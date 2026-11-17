import React, {useState} from 'react';
import {Keyboard, Pressable, ScrollView, StyleSheet, View} from 'react-native';
import {mediaURI} from '../native';
import {errorText, useFlow} from '../navigation';
import {library, useSkater, visibleSkater} from '../state/library';
import {collectionNames, findLine, isReported, lines} from '../state/model';
import type {Collection, Line, Subject} from '../state/model';
import {Film, MediaStage, Poster, timeText} from '../ui/media';
import {useMutation} from '../ui/mutation';
import {Action, Choices, colors, Copy, Empty, Field, Glyph, layout, Notice, Row, Screen} from '../ui/paper';

type Filter = 'all' | Collection;
const filters: Filter[] = ['all', 'street', 'park', 'flat', 'offboard'];

export function Lines() {
  const flow = useFlow();
  const {account, config} = useSkater();
  const [filter, setFilter] = useState<Filter>('all');
  const [revision, setRevision] = useState(0);
  const [limit, setLimit] = useState(12);
  const visible = lines.filter(item => (filter === 'all' || item.collection === filter) &&
    !isReported(account, {kind: 'line', id: item.id}));
  const feature = visible[0];
  const others = visible.slice(1);
  const videos = others.filter(item => item.type === 'video');
  const photos = others.filter(item => item.type === 'photo');
  return <Screen title="Lines" ground="LinesGround" root
    action={<Action title="Post" icon="add" action={() => flow.open({name: 'post'})} />}>
    {!config.media ? <View style={styles.offline}>
      <Glyph name="lines" size={76} color={colors.grip} />
      <Copy size="heading" color={colors.paper} header>Skate films and photos</Copy>
      <Copy color={colors.paper}>The collection is unavailable right now.</Copy>
      <Action title="Open your skate journal" icon="sessions" action={() => flow.select('sessions')} />
    </View> : <>
      <Choices values={filters} value={filter} onChange={value => {setFilter(value); setLimit(12);}}
        label={value => value === 'all' ? 'All' : collectionNames[value]} />
      {feature ? <LineCard item={feature} kind="feature" revision={revision} /> :
        <Empty icon="ramp" title="No lines in this collection" note="Try another terrain." />}
      {videos.length > 0 && <View style={layout.stack}>
        <Copy size="heading" header>Skate films</Copy>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} directionalLockEnabled contentContainerStyle={styles.strip}>
          {videos.map(item => <LineCard key={item.id} item={item} kind="film" revision={revision} />)}
        </ScrollView>
      </View>}
      {photos.length > 0 && <View style={layout.stack}>
        <Copy size="heading" header>{filter === 'offboard' ? 'Around the session' : 'Contact sheet'}</Copy>
        <View style={styles.photoGrid}>
          {photos.slice(0, limit).map(item => <LineCard key={item.id} item={item} kind="photo" revision={revision} />)}
        </View>
        {photos.length > limit && <Action title="More photos" icon="add" tone="paper" action={() => setLimit(value => value + 12)} />}
      </View>}
      <Action title="Refresh lines" icon="load" tone="paper" action={() => setRevision(value => value + 1)} />
    </>}
  </Screen>;
}

function LineCard({item, kind, revision}: {item: Line; kind: 'feature' | 'photo' | 'film'; revision: number}) {
  const flow = useFlow();
  const {config} = useSkater();
  const feature = kind === 'feature';
  const video = item.type === 'video';
  return <Pressable
    accessibilityRole="button" accessibilityLabel={`${item.title}, ${collectionNames[item.collection]}, ${video ? 'film' : 'photo'}`}
    onPress={() => flow.open({name: 'line', id: item.id})}
    style={({pressed}) => [styles.card, kind === 'film' && styles.stripItem, kind === 'photo' && styles.gridItem,
      feature && layout.ink, {opacity: pressed ? 0.74 : 1}]}
  >
    <View style={{aspectRatio: feature ? 1.02 : kind === 'film' ? 0.78 : 1.12}}>
      {flow.visible && <Poster uri={mediaURI(config, item.poster ?? item.path)} label={item.title} revision={revision} />}
      {video && <View style={styles.playMark}>
        <Glyph name="play" size={15} color={colors.paper} />
        {item.duration !== null && <Copy size="caption" color={colors.paper}>{timeText(item.duration)}</Copy>}
      </View>}
    </View>
    <View style={{padding: feature ? 13 : 8, gap: 3}}>
      <Copy size="caption" color={feature ? colors.grip : colors.muted}>{collectionNames[item.collection]}</Copy>
      <Copy size={feature ? 'heading' : 'label'} color={feature ? colors.paper : colors.ink}>{item.title}</Copy>
    </View>
  </Pressable>;
}

export function LineDetails({id}: {id: string}) {
  const flow = useFlow();
  const {archive, account, config} = useSkater();
  const [comment, setComment] = useState('');
  const [editing, setEditing] = useState<string>();
  const {busy: submitting, run} = useMutation();
  const item = findLine(id);
  const visible = item && !isReported(account, {kind: 'line', id});
  const liked = account.liked.includes(id);
  const saved = account.saved.includes(id);
  const likes = Object.values(archive.accounts).filter(person => visibleSkater(archive, account, person.id) && person.liked.includes(id)).length;
  const comments = archive.comments.filter(reply => reply.lineID === id && visibleSkater(archive, account, reply.authorID) &&
    !isReported(account, {kind: 'comment', id: reply.id})).sort((a, b) => a.date - b.date);
  const openReport = (subject: Subject) => flow.open({name: 'report', subject});
  function submit() {
    void run(() => library.saveComment(id, comment, editing), () => {
      setComment('');
      setEditing(undefined);
      Keyboard.dismiss();
    });
  }
  return <Screen title={item?.title ?? 'Line'} ground="LinesGround" editing>
    {visible ? <>
      {item.type === 'video' ? <Film id={id} title={item.title} uri={mediaURI(config, item.path)}
        poster={mediaURI(config, item.poster)} expand={() => flow.open({name: 'lineViewer', id})}
        report={() => openReport({kind: 'line', id})} /> : <>
        <View style={{aspectRatio: Math.max(0.8, Math.min(1.62, item.width / Math.max(1, item.height)))}}>
          {flow.visible && <Poster uri={mediaURI(config, item.path)} label={item.title} retry />}
        </View>
        <Action title="View photo" icon="expand" tone="paper" action={() => flow.open({name: 'lineViewer', id})} />
      </>}
      <Copy size="label" color={colors.muted}>{collectionNames[item.collection]} · Nina collection</Copy>
      <View style={layout.row}>
        <Action title={`${liked ? 'Liked' : 'Like'} (${likes})`} icon={liked ? 'liked' : 'like'} tone="paper"
          selected={liked} action={() => {void library.toggleLine(id, 'liked').catch(error => flow.notice(errorText(error)));}} />
        <Action title={saved ? 'Saved' : 'Save'} icon={saved ? 'saved' : 'save'} tone="paper"
          selected={saved} action={() => {void library.toggleLine(id, 'saved').catch(error => flow.notice(errorText(error)));}} />
        <Action title="Report" icon="flag" tone="paper" action={() => openReport({kind: 'line', id})} />
      </View>
      {item.collection !== 'offboard' && <>
        <Row title="Practice this line" detail="Use it as a reference in your trick log." icon="sessions"
          action={() => flow.open({name: 'trick', reference: id})} />
        <Row title="Add a related spot" detail="Keep the terrain and reference together." icon="spot"
          action={() => flow.open({name: 'spotEditor', reference: id})} />
      </>}
      <View style={layout.stack}>
        <Copy size="heading" header>Comments</Copy>
        {!comments.length && <Notice>Start the discussion about this line.</Notice>}
        {comments.map(reply => {
          const person = visibleSkater(archive, account, reply.authorID);
          return <View key={reply.id} style={layout.section}>
            <Action title={person?.profile.name ?? 'Skater'} icon="avatar" tone="plain"
              action={() => flow.open({name: 'profile', id: reply.authorID})} />
            <Copy>{reply.body}</Copy>
            <View style={layout.row}>
              {reply.authorID === account.id ? <>
                <Action title="Edit" icon="edit" tone="plain" action={() => {setComment(reply.body); setEditing(reply.id);}} />
                <Action title="Delete" tone="plain" action={() => {void library.removeComment(reply.id).then(() => {
                  if (editing === reply.id) {setEditing(undefined); setComment('');}
                }).catch(error => flow.notice(errorText(error)));}} />
              </> : <>
                <Action title="Report" icon="flag" tone="plain" action={() => openReport({kind: 'comment', id: reply.id})} />
                <Action title="Block skater" tone="plain" action={() => flow.open({name: 'block', id: reply.authorID})} />
              </>}
            </View>
          </View>;
        })}
        <Field label={editing ? 'Edit your comment' : 'Add a comment'} value={comment} onChangeText={setComment} multiline />
        <View style={layout.row}>
          <Action title={editing ? 'Save comment' : 'Post comment'} icon="send"
            disabled={submitting || !comment.trim()} action={submit} />
          {editing && <Action title="Cancel" tone="paper" action={() => {setComment(''); setEditing(undefined);}} />}
        </View>
      </View>
    </> : <Empty icon="flag" title="Line unavailable" note="Return to the collection to continue browsing." />}
  </Screen>;
}

export function LineViewer({id}: {id: string}) {
  const flow = useFlow();
  const {account, config} = useSkater();
  const item = findLine(id);
  return <MediaStage title={item?.title ?? 'Line'}>
    {item && !isReported(account, {kind: 'line', id}) ? (
      item.type === 'video' ? <Film id={id} title={item.title} uri={mediaURI(config, item.path)}
        poster={mediaURI(config, item.poster)} fullscreen report={() => flow.open({name: 'report', subject: {kind: 'line', id}})} /> :
        <Poster uri={mediaURI(config, item.path)} label={item.title} contain retry />
    ) : <Empty icon="flag" title="Line hidden" />}
  </MediaStage>;
}

const styles = StyleSheet.create({
  strip: {gap: 9},
  stripItem: {width: 144},
  photoGrid: {flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: 12},
  gridItem: {width: '48.5%'},
  card: {backgroundColor: colors.paper, overflow: 'hidden'},
  playMark: {position: 'absolute', bottom: 6, right: 6, flexDirection: 'row', alignItems: 'center', gap: 4, padding: 5, backgroundColor: colors.ink},
  offline: {backgroundColor: colors.ink, padding: 19, gap: 10},
});
