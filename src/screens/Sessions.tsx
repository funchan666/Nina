import React, {useState} from 'react';
import {Image, Pressable, StyleSheet, View} from 'react-native';
import {useFlow} from '../navigation';
import {library, useSkater} from '../state/library';
import {
  attemptMetricsError, collectionNames, dateOf, findLine, now, progress, recordID, spotKey, stances, surfaces, terrains, titleCase,
} from '../state/model';
import type {Attempt, ID, Spot, Stance, Surface, Terrain} from '../state/model';
import {coverArtwork, grounds} from '../ui/artwork';
import {useMutation} from '../ui/mutation';
import {Action, Check, Choices, colors, Copy, Empty, Field, layout, Notice, Row, Screen} from '../ui/paper';

export function Sessions() {
  const flow = useFlow();
  const {account} = useSkater();
  const [section, select] = useState<'Sessions' | 'Plans' | 'Spots'>('Sessions');
  const recorded = account.attempts.filter(item => item.attempts > 0).sort((a, b) => b.date - a.date);
  const plans = account.attempts.filter(item => item.attempts === 0).sort((a, b) => b.date - a.date);
  const cover = account.selectedCover;
  const hasSpots = account.spots.length > 0;
  const entries = section === 'Plans' ? plans : recorded;
  return <Screen title="Sessions" ground="SessionsGround" root
    action={hasSpots
      ? <Action title="Log tricks" icon="add" action={() => flow.open({name: 'trick'})} />
      : <Action title="Add spot" icon="spot" action={() => flow.open({name: 'spotEditor'})} />}>
    <View style={styles.journal}>
      <Image source={cover ? coverArtwork[cover] : grounds.SessionsGround} style={styles.cover} accessible={false} resizeMode="cover" />
      <View style={styles.shade} pointerEvents="none" />
      <Copy size="heading" color={colors.paper} header>{recorded.length
        ? `${recorded.length} ${recorded.length === 1 ? 'session' : 'sessions'} logged`
        : 'Your next session starts here'}</Copy>
      <Copy color={colors.paper}>{account.spots.length} saved {account.spots.length === 1 ? 'spot' : 'spots'} · {plans.length} practice {plans.length === 1 ? 'plan' : 'plans'}</Copy>
      <Action title="Change cover" icon="grip" tone="paper" action={() => flow.open({name: 'covers'})} />
    </View>
    <Choices values={['Sessions', 'Plans', 'Spots'] as const} value={section} onChange={select}
      label={value => value === 'Plans' ? 'Practice plans' : value === 'Spots' ? 'Spot book' : 'Session log'} />
    <View style={layout.split}>
      <Copy size="heading" header>{section === 'Spots' ? 'Your spot book' : section === 'Plans' ? 'Up next' : 'Your sessions'}</Copy>
      {section === 'Spots' && hasSpots ? <Action title="Add spot" icon="add" tone="paper" action={() => flow.open({name: 'spotEditor'})} /> : null}
    </View>
    {section === 'Spots' ? <>
      {!hasSpots ? <>
        <Empty icon="ramp" title="Save a spot you love" note="Keep the obstacles and access details ready for your next visit." />
        <Action title="Save your first spot" icon="spot" action={() => flow.open({name: 'spotEditor'})} />
      </> : null}
      {account.spots.map(spot => {
        const visits = recorded.filter(item => item.spotID === spot.id).length;
        return <Row key={spot.id} title={spot.name}
          detail={`${collectionNames[spot.terrain]} · ${spot.obstacle} · ${visits} ${visits === 1 ? 'visit' : 'visits'}`}
          icon="spot" action={() => flow.open({name: 'spot', id: spot.id})} />;
      })}
    </> : <>
      {!entries.length ? <>
        <Empty icon="deck" title={section === 'Plans' ? 'Plan your next trick' : 'Keep the session going'}
          note={section === 'Plans' ? 'Choose a trick and save it with zero tries to make a practice plan.' : 'Log your tries and the tricks you landed. Small wins count.'} />
        <Action title={hasSpots ? section === 'Plans' ? 'Make a practice plan' : 'Log your first session' : 'Start with a spot'}
          icon={hasSpots ? 'sessions' : 'spot'} action={() => flow.open(hasSpots ? {name: 'trick'} : {name: 'spotEditor'})} />
      </> : null}
      {entries.map(attempt => <TrickRow key={attempt.id} attempt={attempt}
        spot={account.spots.find(item => item.id === attempt.spotID)?.name} />)}
    </>}
  </Screen>;
}

function TrickRow({attempt, spot}: {attempt: Attempt; spot?: string}) {
  const flow = useFlow();
  const date = dateOf(attempt.date);
  return <Pressable accessibilityRole="button"
    onPress={() => flow.open({name: 'trick', id: attempt.id, spot: attempt.spotID, reference: attempt.referenceID})}
    style={({pressed}) => [styles.ledger, {opacity: pressed ? 0.74 : 1}]}>
    <View style={styles.ledgerDate}>
      <Copy size="caption" color={colors.paper}>{date.toLocaleDateString('en', {month: 'short'})}</Copy>
      <Copy size="card" color={colors.paper}>{date.getDate()}</Copy>
    </View>
    <View style={layout.fill}>
      <Copy size="card">{attempt.trick}</Copy>
      {spot && <Copy size="label">{spot}</Copy>}
      <Copy size="caption">{titleCase(attempt.stance)} · {progress(attempt)}</Copy>
      <Copy size="caption" color={colors.muted}>{attempt.attempts > 0
        ? `${attempt.landings} landed / ${attempt.attempts} tries · Goal ${attempt.goal}`
        : `Landing goal ${attempt.goal}`}</Copy>
    </View>
  </Pressable>;
}

export function SpotDetails({id}: {id: ID}) {
  const flow = useFlow();
  const {account} = useSkater();
  const spot = account.spots.find(item => item.id === id);
  const attempts = account.attempts.filter(item => item.spotID === id).sort((a, b) => b.date - a.date);
  const reference = findLine(spot?.referenceID);
  return <Screen title={spot?.name ?? 'Spot'} ground="SessionsGround">
    {spot ? <>
      <View style={layout.section}>
        <Copy size="label" color={colors.muted}>{collectionNames[spot.terrain]} / {titleCase(spot.condition)}</Copy>
        <Copy size="heading">{spot.obstacle}</Copy>
        {spot.accessNotes ? <Copy>{spot.accessNotes}</Copy> : null}
      </View>
      <Action title="Log tricks here" icon="add" action={() => flow.open({name: 'trick', spot: id, reference: spot.referenceID})} />
      <Row title="Skaters at this spot" detail="Practice summaries skaters chose to share." icon="crew"
        action={() => flow.open({name: 'crewAtSpot', spotKey: spotKey(spot), title: spot.name})} />
      {reference && <Row title={reference.title} detail="Reference line" icon="lines"
        action={() => flow.open({name: 'line', id: reference.id})} />}
      <Action title="Edit spot" icon="edit" tone="paper" action={() => flow.open({name: 'spotEditor', id})} />
      <Copy size="heading" header>Visits and plans</Copy>
      {!attempts.length ? <Notice>Log tries here to keep a record of this spot.</Notice> : null}
      {attempts.map(attempt => <TrickRow key={attempt.id} attempt={attempt} />)}
    </> : <Empty icon="spot" title="Spot unavailable" />}
  </Screen>;
}

export function SpotEditor({id, reference}: {id?: ID; reference?: ID}) {
  const flow = useFlow();
  const {account} = useSkater();
  const original = account.spots.find(item => item.id === id);
  const line = findLine(original?.referenceID ?? reference);
  const [name, setName] = useState(original?.name ?? '');
  const [obstacle, setObstacle] = useState(original?.obstacle ?? '');
  const [notes, setNotes] = useState(original?.accessNotes ?? '');
  const [terrain, setTerrain] = useState<Terrain>(original?.terrain ?? (line?.collection === 'offboard' ? 'street' : line?.collection ?? 'street'));
  const [condition, setCondition] = useState<Surface>(original?.condition ?? 'smooth');
  const [confirm, setConfirm] = useState(false);
  const {busy, run} = useMutation();

  function save() {
    const draft: Spot = {
      id: original?.id ?? recordID(), name, obstacle, terrain, condition, accessNotes: notes,
      referenceID: original?.referenceID ?? reference, createdAt: original?.createdAt ?? now(),
    };
    void run(() => library.saveSpot(draft), () => {
      flow.back();
      flow.notice('Spot saved.');
    });
  }
  return <Screen title={id ? 'Edit spot' : 'Save a spot'} ground="SessionsGround" editing>
    {!id || original ? <>
      <Field label="Spot name" value={name} onChangeText={setName} />
      <Field label="Obstacle or feature" value={obstacle} onChangeText={setObstacle} />
      <View style={layout.stack}>
        <Copy size="label">Terrain</Copy>
        <Choices values={terrains} value={terrain} onChange={setTerrain} label={value => collectionNames[value]} />
      </View>
      <View style={layout.stack}>
        <Copy size="label">Surface</Copy>
        <Choices values={surfaces} value={condition} onChange={setCondition} label={titleCase} />
      </View>
      <Field label="Access notes" value={notes} onChangeText={setNotes} multiline />
      {line && <Notice>Reference · {line.title}</Notice>}
      <Action title="Save spot" icon="check" action={save} disabled={busy || !name.trim() || !obstacle.trim()} />
      {id ? (confirm ? <View style={layout.stack}>
        <Notice>Remove this spot from your book?</Notice>
        <Action title="Remove spot" tone="danger" disabled={busy} action={() => {
          void run(() => library.removeSpot(id), () => {flow.back(); flow.notice('Spot removed.');});
        }} />
        <Action title="Keep spot" tone="paper" action={() => setConfirm(false)} />
      </View> : <Action title="Remove spot" tone="paper" action={() => setConfirm(true)} />) : null}
    </> : <Notice error>This spot is no longer in your book.</Notice>}
  </Screen>;
}

type Counts = {attempts: string; landings: string; goal: string; minutes: string};
const numberFields = [
  ['attempts', 'Tries'], ['landings', 'Landed'], ['goal', 'Landing goal'], ['minutes', 'Minutes'],
] as const;

function wholeCount(text: string) {
  return /^\d+$/.test(text.trim()) ? Number(text) : Number.NaN;
}

export function TrickEditor({id, spot, reference}: {id?: ID; spot?: ID; reference?: ID}) {
  const flow = useFlow();
  const {account} = useSkater();
  const original = account.attempts.find(item => item.id === id);
  const [selected, select] = useState(original?.spotID ?? spot ?? account.spots[0]?.id);
  const [trick, setTrick] = useState(original?.trick ?? '');
  const [stance, setStance] = useState<Stance>(original?.stance ?? account.profile.stance);
  const [counts, setCounts] = useState<Counts>({
    attempts: String(original?.attempts ?? 0), landings: String(original?.landings ?? 0),
    goal: String(original?.goal ?? 3), minutes: String(original?.minutes ?? 0),
  });
  const [notes, setNotes] = useState(original?.notes ?? '');
  const [shared, setShared] = useState(original?.shareWithCrew ?? false);
  const [confirm, setConfirm] = useState(false);
  const [showIssue, setShowIssue] = useState(false);
  const {busy, run} = useMutation();
  const spotID = selected && account.spots.some(item => item.id === selected) ? selected : account.spots[0]?.id;
  const line = findLine(original?.referenceID ?? reference);
  const metrics = {
    attempts: wholeCount(counts.attempts), landings: wholeCount(counts.landings),
    goal: wholeCount(counts.goal), minutes: wholeCount(counts.minutes),
  };
  const issue = attemptMetricsError(metrics);
  const isPlan = metrics.attempts === 0;

  function save() {
    if (!spotID) {
      flow.notice('Choose a spot.');
      return;
    }
    if (issue) {
      setShowIssue(true);
      return;
    }
    const draft: Attempt = {
      id: original?.id ?? recordID(), spotID, trick, stance, notes,
      ...metrics,
      referenceID: original?.referenceID ?? reference, shareWithCrew: shared, date: original?.date ?? now(),
    };
    void run(() => library.saveAttempt(draft), () => {
      flow.back();
      flow.notice(id ? 'Trick log updated.' : isPlan ? 'Practice plan saved.' : 'Session logged.');
    });
  }

  return <Screen title={id ? 'Edit trick log' : 'Log tricks'} ground="SessionsGround" editing>
    {!account.spots.length ? <>
      <Empty icon="spot" title="Add a spot first" note="A trick log needs a spot so you can return to the same terrain." />
      <Action title="Save a spot" icon="add" action={() => flow.open({name: 'spotEditor', reference})} />
    </> : (!id || original ? <>
      <View style={layout.stack}>
        <Copy size="label">Where did you skate?</Copy>
        <Choices values={account.spots.map(item => item.id)} value={spotID} onChange={select}
          label={value => account.spots.find(item => item.id === value)?.name ?? 'Spot'} />
      </View>
      <Field label="Trick" value={trick} onChangeText={setTrick} />
      <View style={layout.stack}>
        <Copy size="label">Stance</Copy>
        <Choices values={stances} value={stance} onChange={setStance} label={titleCase} />
      </View>
      <View style={layout.section}>
        <View style={styles.numberFields}>
          {numberFields.map(([key, label]) => <View key={key} style={styles.numberField}>
            <Field label={label} value={counts[key]} keyboardType="number-pad" style={styles.numberInput}
              onChangeText={value => setCounts(current => ({...current, [key]: value}))} />
          </View>)}
        </View>
        <Copy size="caption" color={colors.muted}>Use 0 tries to save a practice plan.</Copy>
      </View>
      <Field label="Practice notes" value={notes} onChangeText={setNotes} multiline />
      <Check title="Show session summary in Crew" value={shared} toggle={() => setShared(value => !value)} />
      {line && <Notice>Reference · {line.title}</Notice>}
      {showIssue && issue ? <Notice error>{issue}</Notice> : null}
      <Action title={id ? 'Save changes' : isPlan ? 'Save practice plan' : 'Save session'}
        icon="check" action={save} disabled={busy || !trick.trim()} />
      {id ? <>
        <Action title="Log another session" icon="add" tone="paper"
          action={() => flow.open({name: 'trick', spot: spotID, reference: original?.referenceID ?? reference})} />
        {confirm ? <View style={layout.stack}>
          <Notice>Remove this trick log?</Notice>
          <Action title="Remove log" tone="danger" disabled={busy} action={() => {
            void run(() => library.removeAttempt(id), () => {flow.back(); flow.notice('Trick log removed.');});
          }} />
          <Action title="Keep log" tone="paper" action={() => setConfirm(false)} />
        </View> : <Action title="Remove log" tone="paper" action={() => setConfirm(true)} />}
      </> : null}
    </> : <Notice error>This trick log is unavailable.</Notice>)}
  </Screen>;
}

const styles = StyleSheet.create({
  journal: {minHeight: 138, backgroundColor: colors.ink, padding: 15, justifyContent: 'center', gap: 8, overflow: 'hidden'},
  cover: {...StyleSheet.absoluteFillObject, width: '100%', height: '100%'},
  shade: {...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(24,38,32,0.59)'},
  ledger: {padding: 9, gap: 12, flexDirection: 'row', alignItems: 'flex-start', backgroundColor: colors.paper},
  ledgerDate: {backgroundColor: colors.ink, padding: 11, minWidth: 51},
  numberFields: {flexDirection: 'row', flexWrap: 'wrap', gap: 9},
  numberField: {flexBasis: '45%', flexGrow: 1, flexShrink: 1, minWidth: 0},
  numberInput: {backgroundColor: colors.sage, fontVariant: ['tabular-nums']},
});
