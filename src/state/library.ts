import {useSyncExternalStore} from 'react';
import {platform} from '../native';
import type {Configuration, Identity, VerifiedPurchase} from '../native';
import {
  balance, checkedText, coverPrice, decodeArchive, emptyArchive, isReported, now, packs, recordID, spotKey,
} from './model';
import type {
  Account, Archive, Attachment, Attempt, Cover, Event, ID, Profile, Spot, Subject, Submission,
} from './model';

type Snapshot = {
  archive: Archive;
  config: Configuration | null;
  activeID: ID | null;
  status: 'loading' | 'ready' | 'error';
  issue?: string;
  warning?: string;
};

function accountOrThrow(archive: Archive, id: ID | null) {
  const account = id ? archive.accounts[id] : undefined;
  if (!account) {
    throw new Error('Sign in to keep your changes.');
  }
  return account;
}

export function visibleSkater(archive: Archive, viewer: Account, id: ID) {
  const peer = archive.accounts[id];
  if (!peer || viewer.blocked.includes(id) || peer.blocked.includes(viewer.id) || isReported(viewer, {kind: 'skater', id})) {
    return undefined;
  }
  return peer;
}

export function follows(archive: Archive, viewer: Account, id: ID) {
  return archive.follows.some(edge => edge.follower === viewer.id && edge.skater === id);
}

export function canContact(archive: Archive, viewer: Account, peer: ID) {
  const member = visibleSkater(archive, viewer, peer);
  return Boolean(member && peer !== viewer.id && follows(archive, viewer, peer) &&
    follows(archive, member, viewer.id) && !isReported(viewer, {kind: 'conversation', id: peer}));
}

export function relationships(archive: Archive, viewer: Account, id: ID, incoming: boolean) {
  const ids = incoming
    ? archive.follows.filter(edge => edge.skater === id).map(edge => edge.follower)
    : archive.follows.filter(edge => edge.follower === id).map(edge => edge.skater);
  return ids.flatMap(member => {
    const person = visibleSkater(archive, viewer, member);
    return person ? [person] : [];
  }).sort((a, b) => a.profile.name.localeCompare(b.profile.name));
}

export function sharedAttempts(account: Account, key?: string) {
  const spotIDs = new Set(account.spots.filter(spot => !key || spotKey(spot) === key).map(spot => spot.id));
  return account.attempts.filter(attempt => attempt.shareWithCrew && attempt.attempts > 0 && spotIDs.has(attempt.spotID));
}

export function visibleActivity(archive: Archive, viewer: Account) {
  return archive.activity.filter(event => event.owner === viewer.id &&
    (!event.actor || visibleSkater(archive, viewer, event.actor)));
}

function appendEvent(archive: Archive, fields: Omit<Event, 'id' | 'date' | 'read'>) {
  archive.activity.unshift({...fields, id: recordID(), date: now(), read: false});
}

class NinaLibrary {
  private state: Snapshot = {archive: emptyArchive(), config: null, activeID: null, status: 'loading'};
  private subscribers = new Set<() => void>();
  private queue: Promise<void> = Promise.resolve();

  snapshot = () => this.state;
  subscribe = (notify: () => void) => {
    this.subscribers.add(notify);
    return () => this.subscribers.delete(notify);
  };

  private publish(patch: Partial<Snapshot>) {
    this.state = {...this.state, ...patch};
    this.subscribers.forEach(notify => notify());
  }

  private serial<T>(work: () => Promise<T>) {
    const result = this.queue.then(work);
    this.queue = result.then(() => undefined, () => undefined);
    return result;
  }

  private clone(): Archive {
    return JSON.parse(JSON.stringify(this.state.archive)) as Archive;
  }

  private async save(archive: Archive) {
    await platform('writeArchive', {json: JSON.stringify(archive)});
    this.publish({archive});
  }

  load = () => this.serial(async () => {
    if (this.state.status === 'ready') {
      return;
    }
    this.publish({status: 'loading', issue: undefined});
    try {
      const stored = await platform('bootstrap');
      const archive = decodeArchive(stored.json, stored.legacy);
      if (stored.legacy) {
        await platform('writeArchive', {json: JSON.stringify(archive), removeLegacy: true});
      } else if (stored.legacyNeedsCleanup) {
        await platform('cleanLegacy');
      }
      const activeID = stored.activeID && archive.accounts[stored.activeID] ? stored.activeID : null;
      if (stored.activeID && !activeID) {
        await platform('session', {id: null});
      }
      await Promise.allSettled(archive.retiredAccounts.map(owner => platform('removeAccount', {owner})));
      this.publish({archive, config: stored.config, activeID, status: 'ready'});
    } catch (error) {
      this.publish({status: 'error', issue: error instanceof Error ? error.message : 'Could not open the journal.'});
    }
  });

  private edit<T>(change: (archive: Archive, account: Account) => T) {
    const actor = this.state.activeID;
    return this.serial(async () => {
      if (actor !== this.state.activeID) {
        throw new Error('Switch back to the profile that owns these changes.');
      }
      const archive = this.clone();
      const result = change(archive, accountOrThrow(archive, actor));
      await this.save(archive);
      return result;
    });
  }

  private open(identity: Identity, method: Account['method']) {
    return this.serial(async () => {
      if (this.state.activeID) {
        return;
      }
      const archive = this.clone();
      const existing = Object.values(archive.accounts).find(account => account.loginKey === identity.key);
      if (!existing) {
        const name = Array.from(identity.name?.trim() || 'Skater').slice(0, 32).join('');
        archive.accounts[identity.id] = {
          id: identity.id,
          loginKey: identity.key,
          method,
          profile: {name, stance: 'regular', bio: ''},
          agreementDate: now(),
          blocked: [], saved: [], liked: [], spots: [], attempts: [], submissions: [], drafts: [], reports: [], covers: [],
          grip: [{id: 'welcome', label: 'Welcome Grip', amount: 20, date: now()}],
        };
        await this.save(archive);
      }
      const id = existing?.id ?? identity.id;
      await platform('session', {id});
      this.publish({activeID: id, warning: undefined});
    });
  }

  async signIn(email: string, password: string) {
    const address = email.trim().toLowerCase();
    if (address.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(address)) {
      throw new Error('Enter a valid email address.');
    }
    if (!password) {
      throw new Error('Enter a password to continue.');
    }
    await this.open(await platform('identity', {value: 'email:' + address}), 'email');
  }

  async signInApple() {
    await this.open(await platform('appleSignIn'), 'apple');
  }

  signOut(appleOnly = false) {
    return this.serial(async () => {
      const active = this.state.activeID;
      if (active && (!appleOnly || this.state.archive.accounts[active]?.method === 'apple')) {
        await platform('session', {id: null});
        await platform('releaseFilm');
        this.publish({activeID: null});
      }
    });
  }

  deleteAccount() {
    const actor = this.state.activeID;
    return this.serial(async () => {
      if (actor !== this.state.activeID) {
        throw new Error('This profile is unavailable.');
      }
      const next = this.clone();
      const {id} = accountOrThrow(next, actor);
      const commentIDs = new Set(next.comments.filter(comment => comment.authorID === id).map(comment => comment.id));
      delete next.accounts[id];
      next.retiredAccounts.push(id);
      next.follows = next.follows.filter(edge => edge.follower !== id && edge.skater !== id);
      next.activity = next.activity.filter(event => event.owner !== id && event.actor !== id);
      next.comments = next.comments.filter(comment => comment.authorID !== id);
      for (const account of Object.values(next.accounts)) {
        account.blocked = account.blocked.filter(member => member !== id);
        account.drafts = account.drafts.filter(draft => draft.peer !== id);
        account.reports = account.reports.filter(({subject}) => {
          if (subject.kind === 'comment') {
            return !commentIDs.has(subject.id);
          }
          return subject.kind === 'line' || subject.id !== id;
        });
      }
      await this.save(next);
      const cleanup = await Promise.allSettled([
        platform('releaseFilm'),
        platform('session', {id: null}),
        platform('removeAccount', {owner: id}),
      ]);
      this.publish({
        activeID: null,
        warning: cleanup.some(result => result.status === 'rejected')
          ? 'Your profile was removed. Nina will retry clearing remaining data the next time it opens.'
          : undefined,
      });
    });
  }

  async updateProfile(draft: Profile) {
    await this.edit((_archive, account) => {
      account.profile = {
        ...draft,
        name: checkedText(draft.name, 'a display name', 32),
        bio: checkedText(draft.bio, 'a bio', 200, false),
      };
    });
  }

  saveSpot(spot: Spot) {
    return this.edit((_archive, account) => {
      const clean = {
        ...spot,
        name: checkedText(spot.name, 'a spot name', 60),
        obstacle: checkedText(spot.obstacle, 'an obstacle', 50),
        accessNotes: checkedText(spot.accessNotes, 'access notes', 280, false),
      };
      if (account.spots.some(existing => existing.id !== spot.id && spotKey(existing) === spotKey(clean))) {
        throw new Error('You already saved this spot.');
      }
      const index = account.spots.findIndex(item => item.id === spot.id);
      if (index >= 0) {
        account.spots[index] = clean;
      } else {
        account.spots.unshift(clean);
      }
    });
  }

  removeSpot(id: ID) {
    return this.edit((_archive, account) => {
      if (account.attempts.some(item => item.spotID === id)) {
        throw new Error('Move or remove the trick logs for this spot first.');
      }
      account.spots = account.spots.filter(spot => spot.id !== id);
    });
  }

  saveAttempt(attempt: Attempt) {
    return this.edit((_archive, account) => {
      const clean = {
        ...attempt,
        trick: checkedText(attempt.trick, 'a trick', 50),
        notes: checkedText(attempt.notes, 'practice notes', 400, false),
      };
      const {attempts, landings, goal, minutes} = clean;
      const whole = [attempts, landings, goal, minutes].every(Number.isInteger);
      if (!whole || attempts < 0 || attempts > 500 || landings < 0 || landings > attempts ||
        goal < 1 || goal > 50 || minutes < 0 || minutes > 480) {
        throw new Error('Use 0–500 tries, landings within tries, a goal of 1–50 and 0–480 minutes.');
      }
      if (!account.spots.some(spot => spot.id === clean.spotID)) {
        throw new Error('Choose a spot before saving.');
      }
      const index = account.attempts.findIndex(item => item.id === clean.id);
      if (index >= 0) {
        account.attempts[index] = clean;
      } else {
        account.attempts.unshift(clean);
      }
    });
  }

  removeAttempt(id: ID) {
    return this.edit((_archive, account) => {
      account.attempts = account.attempts.filter(item => item.id !== id);
    });
  }

  toggleLine(id: ID, field: 'liked' | 'saved') {
    return this.edit((_archive, account) => {
      if (isReported(account, {kind: 'line', id})) {
        throw new Error('This line is hidden.');
      }
      account[field] = account[field].includes(id) ? account[field].filter(item => item !== id) : [...account[field], id];
    });
  }

  saveComment(line: ID, text: string, editing?: ID) {
    return this.edit((archive, account) => {
      if (isReported(account, {kind: 'line', id: line})) {
        throw new Error('This line is hidden.');
      }
      const body = checkedText(text, 'a comment', 400);
      if (editing) {
        const comment = archive.comments.find(item => item.id === editing && item.authorID === account.id && item.lineID === line);
        if (!comment) {
          throw new Error('This comment is unavailable.');
        }
        comment.body = body;
      } else {
        archive.comments.push({id: recordID(), lineID: line, authorID: account.id, body, date: now()});
      }
    });
  }

  removeComment(id: ID) {
    return this.edit((archive, account) => {
      archive.comments = archive.comments.filter(comment => comment.id !== id || comment.authorID !== account.id);
    });
  }

  saveSubmission(post: Submission) {
    return this.edit((archive, account) => {
      const clean = {
        ...post,
        title: checkedText(post.title, 'a title', 60),
        caption: checkedText(post.caption, 'a caption', 400, false),
      };
      const index = account.submissions.findIndex(item => item.id === post.id);
      if (index >= 0) {
        account.submissions[index] = clean;
      } else {
        account.submissions.unshift(clean);
        appendEvent(archive, {owner: account.id, kind: 'submission', detail: clean.title});
      }
    });
  }

  async removeSubmission(id: ID) {
    const removed = await this.edit((_archive, account) => {
      const item = account.submissions.find(post => post.id === id);
      account.submissions = account.submissions.filter(post => post.id !== id);
      return item && {owner: account.id, attachment: item.attachment};
    });
    if (removed) {
      await this.removeAttachment(removed.owner, removed.attachment);
    }
  }

  async removeAttachment(owner: ID, attachment: Attachment) {
    await platform('removeAttachment', {owner, attachment});
  }

  toggleFollow(id: ID) {
    return this.edit((archive, account) => {
      if (id === account.id || !visibleSkater(archive, account, id)) {
        throw new Error('This profile is unavailable.');
      }
      const remove = follows(archive, account, id);
      archive.follows = archive.follows.filter(edge => edge.follower !== account.id || edge.skater !== id);
      archive.activity = archive.activity.filter(event =>
        event.owner !== id || event.actor !== account.id || event.kind !== 'follow');
      if (!remove) {
        archive.follows.push({follower: account.id, skater: id});
        appendEvent(archive, {owner: id, actor: account.id, kind: 'follow', detail: ''});
      }
    });
  }

  block(id: ID, blocked: boolean) {
    return this.edit((archive, account) => {
      if (id === account.id || !archive.accounts[id]) {
        throw new Error('This profile is unavailable.');
      }
      account.blocked = account.blocked.filter(member => member !== id);
      if (blocked) {
        account.blocked.push(id);
        const eachOther = (left?: ID, right?: ID) =>
          (left === id && right === account.id) || (left === account.id && right === id);
        archive.follows = archive.follows.filter(edge => !eachOther(edge.follower, edge.skater));
        archive.activity = archive.activity.filter(event => !eachOther(event.owner, event.actor));
      }
    });
  }

  report(subject: Subject, reason: string) {
    return this.edit((archive, account) => {
      if (!isReported(account, subject)) {
        account.reports.push({id: recordID(), subject, reason, date: now()});
        appendEvent(archive, {owner: account.id, kind: 'report', detail: 'Report recorded. Item hidden.'});
      }
    });
  }

  saveDraft(peer: ID, value: string) {
    return this.edit((archive, account) => {
      if (!canContact(archive, account, peer)) {
        throw new Error('Drafts are available once both skaters follow each other.');
      }
      const body = checkedText(value, 'a message', 600);
      const existing = account.drafts.find(item => item.peer === peer);
      account.drafts = [
        {id: existing?.id ?? recordID(), peer, body, savedAt: now()},
        ...account.drafts.filter(item => item.peer !== peer),
      ];
    });
  }

  removeDraft(peer: ID) {
    return this.edit((_archive, account) => {
      account.drafts = account.drafts.filter(item => item.peer !== peer);
    });
  }

  markRead() {
    return this.edit((archive, account) => {
      visibleActivity(archive, account).forEach(event => { event.read = true; });
    });
  }

  applyCover(cover?: Cover) {
    return this.edit((_archive, account) => {
      if (cover && !account.covers.includes(cover)) {
        if (balance(account) < coverPrice) {
          throw new Error(`You need ${coverPrice} Grip for this cover.`);
        }
        account.covers.push(cover);
        account.grip.push({id: 'cover-' + cover, label: 'Journal cover', amount: -coverPrice, date: now()});
      }
      account.selectedCover = cover;
    });
  }

  recordPurchase(transaction: VerifiedPurchase) {
    return this.serial(async () => {
      const {id, owner, productID, revoked} = transaction;
      const pack = packs.find(item => item.id === productID);
      if (!pack || !owner) {
        return false;
      }
      const archive = this.clone();
      const previous = archive.receipts[id];
      if (previous && (previous.owner !== owner || previous.productID !== productID)) {
        return false;
      }
      const account = archive.accounts[owner];
      if (!account) {
        return archive.retiredAccounts.includes(owner);
      }
      if (previous?.revoked === revoked) {
        return true;
      }
      if (!revoked || previous?.credited) {
        const amount = revoked ? -pack.amount : pack.amount;
        const label = revoked ? 'Apple refund' : previous?.credited ? 'Refund reversed' : pack.name;
        account.grip.push({id: recordID(), label, amount, date: now()});
      }
      archive.receipts[id] = {owner, productID, revoked, credited: Boolean(previous?.credited) || !revoked};
      await this.save(archive);
      return true;
    });
  }
}

export const library = new NinaLibrary();
export function useJournal() {
  return useSyncExternalStore(library.subscribe, library.snapshot);
}

export function useSkater() {
  const {archive, config, activeID} = useJournal();
  if (!config) {
    throw new Error('The journal is unavailable.');
  }
  return {archive, config, account: accountOrThrow(archive, activeID)};
}
