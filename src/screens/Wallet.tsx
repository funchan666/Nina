import React, {useEffect, useRef, useState} from 'react';
import {Image, StyleSheet, View} from 'react-native';
import {platform} from '../native';
import type {Offer} from '../native';
import {useFlow} from '../navigation';
import {library, useSkater} from '../state/library';
import {balance, coverPrice, covers, dateOf, packs} from '../state/model';
import type {Cover} from '../state/model';
import {deliver} from '../state/purchases';
import {coverArtwork} from '../ui/artwork';
import {useMutation} from '../ui/mutation';
import {Action, colors, Copy, Glyph, layout, Notice, Row, Screen} from '../ui/paper';

export function Wallet() {
  const flow = useFlow();
  const {account, config} = useSkater();
  const {busy, run} = useMutation();
  const [offer, setOffer] = useState<Offer>();
  const [status, setStatus] = useState('');
  const visible = useRef(flow.visible);
  useEffect(() => {
    visible.current = flow.visible;
    if (!flow.visible) {
      setOffer(undefined);
    }
    return () => {visible.current = false;};
  }, [flow.visible]);

  function quote(productID: string) {
    void run(async () => {
      setStatus('');
      const product = await platform('quote', {productID});
      if (visible.current && library.snapshot().activeID === account.id) {
        setOffer(product);
      }
    });
  }

  function buy(product: Offer) {
    void run(async () => {
      setStatus('');
      try {
        const result = await platform('purchase', {productID: product.id, owner: account.id});
        switch (result.status) {
          case 'purchased': {
            const success = await deliver(result.transaction);
            setStatus(success ? 'Purchase verified.' : 'This purchase couldn’t be assigned to your profile.');
            break;
          }
          case 'pending': setStatus('Waiting for Apple’s approval.'); break;
          case 'cancelled': setStatus('Purchase canceled.'); break;
          case 'unverified': setStatus('Apple couldn’t verify this purchase.'); break;
          case 'unknown': setStatus('Apple returned an unknown result. Check purchases again.'); break;
        }
      } finally {
        setOffer(undefined);
      }
    });
  }

  function recover() {
    void run(async () => {
      setStatus('');
      const unfinished = await platform('recoverPurchases');
      for (const transaction of unfinished) {
        await deliver(transaction);
      }
      setStatus('Apple purchase check complete.');
    });
  }

  const entries = [...account.grip].reverse();
  return <Screen title="Wallet" ground="CrewGround">
    <View style={styles.balance}>
      <Glyph name="grip" size={46} color={colors.grip} />
      <Copy size="title" color={colors.paper}>{balance(account)} Grip</Copy>
      <Copy color={colors.paper}>Unlock a cover for your skate journal.</Copy>
      <Action title="See journal covers" icon="sessions" tone="paper" disabled={busy}
        action={() => flow.open({name: 'covers'})} />
    </View>
    {config.purchasesEnabled ? (offer ? <View style={layout.section}>
      <Copy size="heading" header>{offer.name}</Copy>
      <Copy>{packs.find(pack => pack.id === offer.id)?.amount ?? 0} Grip</Copy>
      <Copy size="card">{offer.price}</Copy>
      <Action title={busy ? 'Waiting for Apple…' : `Buy for ${offer.price}`} icon="grip" disabled={busy} action={() => buy(offer)} />
      <Action title="Cancel" tone="paper" disabled={busy} action={() => setOffer(undefined)} />
    </View> : <View style={layout.stack}>
      <Copy size="heading" header>Grip packs</Copy>
      {busy && <Notice>Checking with Apple…</Notice>}
      {packs.map(pack => <Row key={pack.id} title={pack.name} detail={`${pack.amount} Grip · View Apple price`}
        icon="grip" disabled={busy} action={() => quote(pack.id)} />)}
      <Action title="Check Apple purchases" icon="load" tone="paper" action={recover} disabled={busy} />
      <Copy size="caption" color={colors.muted}>Apple can finish pending deliveries. Used Grip doesn’t restore.</Copy>
    </View>) : <Notice>Grip packs are currently unavailable.</Notice>}
    {status ? <Notice>{status}</Notice> : null}
    <Copy size="heading" header>Grip history</Copy>
    {!entries.length && <Notice>Your Grip changes will appear here.</Notice>}
    {entries.map(entry => <View key={entry.id} style={[layout.section, layout.split]}>
      <View style={layout.fill}>
        <Copy size="label">{entry.label}</Copy>
        <Copy size="caption" color={colors.muted}>{dateOf(entry.date).toLocaleDateString()}</Copy>
      </View>
      <Copy size="label">{entry.amount > 0 ? '+' : ''}{entry.amount}</Copy>
    </View>)}
  </Screen>;
}

const coversIDs = Object.keys(covers) as Cover[];

export function CoverShop() {
  const flow = useFlow();
  const {account} = useSkater();
  const {busy, run} = useMutation();
  const [confirm, setConfirm] = useState<Cover>();
  function apply(cover?: Cover) {
    void run(() => library.applyCover(cover), () => {
      setConfirm(undefined);
      flow.notice(cover ? 'Journal cover applied.' : 'Standard cover applied.');
    });
  }
  return <Screen title="Journal covers" ground="SessionsGround">
    <Notice>{balance(account)} Grip available</Notice>
    {coversIDs.map(id => <View key={id} style={styles.coverRow}>
      <Image source={coverArtwork[id]} style={{width: 76, height: 108}} accessible={false} resizeMode="cover" />
      <View style={[layout.fill, layout.stack]}>
        <Copy size="card">{covers[id]}</Copy>
        {account.selectedCover === id ? <Copy size="caption">Applied</Copy> :
          account.covers.includes(id) ? <Action title="Apply cover" icon="check" tone="paper" disabled={busy} action={() => apply(id)} /> :
          confirm === id ? <>
            <Action title={`Spend ${coverPrice} Grip`} icon="grip" disabled={busy} action={() => apply(id)} />
            <Action title="Cancel" tone="plain" disabled={busy} action={() => setConfirm(undefined)} />
          </> : <Action title={`Unlock · ${coverPrice} Grip`} icon="grip" disabled={busy} action={() => setConfirm(id)} />}
      </View>
    </View>)}
    {account.selectedCover && <Action title="Use standard cover" icon="deck" tone="paper" disabled={busy} action={() => apply()} />}
    <Action title="Open wallet" icon="grip" tone="paper" disabled={busy} action={() => flow.open({name: 'wallet'})} />
  </Screen>;
}

const styles = StyleSheet.create({
  balance: {backgroundColor: colors.ink, padding: 14, gap: 6},
  coverRow: {flexDirection: 'row', padding: 10, alignItems: 'center', gap: 12, backgroundColor: colors.paper},
});
