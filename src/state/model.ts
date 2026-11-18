import media from '../../Nina/Resources/LinesCatalog.json';

export type ID = string;
export type Format = 'photo' | 'video';
export type Terrain = 'street' | 'park' | 'flat';
export type Collection = Terrain | 'offboard';
export type Stance = 'regular' | 'goofy' | 'switch' | 'fakie';
export type Surface = 'smooth' | 'rough' | 'waxed' | 'damp';
export type Cover = 'bowl' | 'wax' | 'night';

export type Line = {
  id: ID;
  title: string;
  type: Format;
  collection: Collection;
  path: string;
  poster: string | null;
  width: number;
  height: number;
  duration: number | null;
};

export type Attachment = {type: Format; file: string; posterFile?: string};
export type Spot = {
  id: ID;
  name: string;
  terrain: Terrain;
  obstacle: string;
  condition: Surface;
  accessNotes: string;
  referenceID?: ID;
  createdAt: number;
};
export type Attempt = {
  id: ID;
  spotID: ID;
  trick: string;
  stance: Stance;
  attempts: number;
  landings: number;
  goal: number;
  minutes: number;
  notes: string;
  referenceID?: ID;
  shareWithCrew: boolean;
  date: number;
};
export type Profile = {name: string; stance: Stance; bio: string; avatar?: Attachment};
export type Follow = {follower: ID; skater: ID};
export type Draft = {id: ID; peer: ID; body: string; savedAt: number};
export type ChatMessage = {id: ID; sender: ID; recipient: ID; body: string; date: number};
export type LineComment = {id: ID; lineID: ID; authorID: ID; body: string; date: number};
export type Submission = {
  id: ID;
  title: string;
  caption: string;
  attachment: Attachment;
  status: 'Awaiting review';
  createdAt: number;
};
export type Event = {
  id: ID;
  owner: ID;
  actor?: ID;
  kind: 'follow' | 'submission' | 'report' | 'message';
  messageID?: ID;
  detail: string;
  date: number;
  read: boolean;
};
export type Subject = {kind: 'line' | 'skater' | 'comment' | 'conversation'; id: ID};
export type Report = {id: ID; subject: Subject; reason: string; date: number};
export type GripEntry = {id: ID; label: string; amount: number; date: number};
export type GripReceipt = {owner: ID; productID: ID; credited: boolean; revoked: boolean};
export type Account = {
  id: ID;
  loginKey: string;
  method: 'email' | 'apple';
  profile: Profile;
  agreementDate: number;
  blocked: ID[];
  saved: ID[];
  liked: ID[];
  spots: Spot[];
  attempts: Attempt[];
  submissions: Submission[];
  drafts: Draft[];
  reports: Report[];
  grip: GripEntry[];
  covers: Cover[];
  selectedCover?: Cover;
};
export type Archive = {
  version: 3;
  accounts: Record<ID, Account>;
  follows: Follow[];
  comments: LineComment[];
  messages: ChatMessage[];
  activity: Event[];
  receipts: Record<ID, GripReceipt>;
  retiredAccounts: ID[];
};

export const lines = media as Line[];
export function findLine(id?: ID) {
  return lines.find(line => line.id === id);
}

export const collectionNames: Record<Collection, string> = {
  street: 'Street',
  park: 'Park',
  flat: 'Flatground',
  offboard: 'Off the Board',
};
export const terrains = ['street', 'park', 'flat'] as const;
export const stances = ['regular', 'goofy', 'switch', 'fakie'] as const;
export const surfaces = ['smooth', 'rough', 'waxed', 'damp'] as const;
export const covers = {
  bowl: 'Bowl Print',
  wax: 'Curb Print',
  night: 'After Hours',
} as const;
export const coverPrice = 60;

const skuPrefix = 'com.funchan666.nina.placeholder.grip.';
export const packs = [
  {slug: 'pocket', name: 'Pocket roll', amount: 60},
  {slug: 'curb', name: 'Curb pack', amount: 180},
  {slug: 'park', name: 'Park pack', amount: 340},
  {slug: 'street', name: 'Street pack', amount: 780},
  {slug: 'line', name: 'Line pack', amount: 1700},
  {slug: 'crew', name: 'Crew pack', amount: 4600},
  {slug: 'tour', name: 'Tour pack', amount: 10000},
].map(pack => ({...pack, id: skuPrefix + pack.slug}));

export const reasons = [
  'Harassment or threats',
  'Hate or discrimination',
  'Sexual content or child safety',
  'Privacy or impersonation',
  'Credit or copyright',
  'Spam or dangerous activity',
] as const;

// All journal versions keep Foundation Date's reference epoch.
const referenceEpoch = 978307200;
export const now = () => Date.now() / 1000 - referenceEpoch;
export const dateOf = (value: number) => new Date((value + referenceEpoch) * 1000);
export const titleCase = (value: string) => value.charAt(0).toUpperCase() + value.slice(1);

let sequence = 0;
export const recordID = () => `${Date.now().toString(36)}-${(++sequence).toString(36)}-${Math.random().toString(36).slice(2, 9)}`;

export function spotKey(spot: Spot) {
  const name = spot.name.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase('en');
  return `${spot.terrain}:${name}`;
}

export function progress(attempt: Attempt) {
  if (attempt.attempts === 0) {
    return 'Planned';
  }
  return attempt.landings >= attempt.goal ? 'Goal landed' : 'In progress';
}

export function attemptMetricsError({attempts, landings, goal, minutes}: Pick<Attempt, 'attempts' | 'landings' | 'goal' | 'minutes'>) {
  if (!Number.isInteger(attempts) || attempts < 0 || attempts > 500) {
    return 'Enter a whole number from 0 to 500 for tries.';
  }
  if (!Number.isInteger(landings) || landings < 0 || landings > attempts) {
    return 'Enter a whole number for landed tricks, up to your number of tries.';
  }
  if (!Number.isInteger(goal) || goal < 1 || goal > 50) {
    return 'Enter a whole number from 1 to 50 for your landing goal.';
  }
  if (!Number.isInteger(minutes) || minutes < 0 || minutes > 480) {
    return 'Enter a whole number from 0 to 480 for minutes.';
  }
  return null;
}

export function balance(account: Account) {
  return Math.max(0, account.grip.reduce((sum, entry) => sum + entry.amount, 0));
}

export function checkedText(value: string, label: string, limit: number, required = true) {
  const text = value.trim();
  if (required && !text) {
    throw new Error(`Enter ${label}.`);
  }
  if (Array.from(text).length > limit) {
    throw new Error(`Keep ${label} within ${limit} characters.`);
  }
  return text;
}

export function isReported(account: Account, subject: Subject) {
  return account.reports.some(report => report.subject.kind === subject.kind && report.subject.id === subject.id);
}

export function emptyArchive(): Archive {
  return {version: 3, accounts: {}, follows: [], comments: [], messages: [], activity: [], receipts: {}, retiredAccounts: []};
}

type LegacySubject = Partial<Record<Subject['kind'], {_0: ID}>>;
type LegacyAccount = Omit<Account, 'reports'> & {reports: (Omit<Report, 'subject'> & {subject: LegacySubject})[]};

function readSubject(subject: LegacySubject): Subject {
  const kinds = ['line', 'skater', 'comment', 'conversation'] as const;
  const kind = kinds.find(key => typeof subject[key]?._0 === 'string');
  if (!kind || !subject[kind]) {
    throw new Error('A recorded report could not be opened.');
  }
  return {kind, id: subject[kind]._0};
}

function readAccounts(value: Record<ID, LegacyAccount> | (ID | LegacyAccount)[]) {
  if (!Array.isArray(value)) {
    return Object.values(value);
  }
  // Foundation encodes dictionaries keyed by UUID as alternating keys and values.
  if (value.length % 2 !== 0) {
    throw new Error('The saved skate profiles could not be opened.');
  }
  return value.filter((item): item is LegacyAccount => typeof item !== 'string');
}

export function decodeArchive(json: string | null, legacy: boolean): Archive {
  if (!json) {
    return emptyArchive();
  }
  if (!legacy) {
    const saved = JSON.parse(json) as Omit<Archive, 'version'> & {version: 2 | 3};
    if ((saved.version !== 2 && saved.version !== 3) || !saved.accounts || Array.isArray(saved.accounts)) {
      throw new Error('This version cannot open the saved journal.');
    }
    // Earlier version-2 journals had drafts but no conversation history.
    if (saved.version === 2 && saved.messages === undefined) saved.messages = [];
    if (!Array.isArray(saved.messages) || saved.messages.some(message => !message ||
      typeof message.id !== 'string' || typeof message.sender !== 'string' || typeof message.recipient !== 'string' ||
      typeof message.body !== 'string' || !Number.isFinite(message.date))) {
      throw new Error('A saved conversation could not be opened.');
    }
    return {...saved, version: 3};
  }
  const old = JSON.parse(json) as Omit<Archive, 'version' | 'accounts'> & {
    version?: number;
    accounts?: Record<ID, LegacyAccount> | (ID | LegacyAccount)[];
  };
  if (old.version !== undefined && old.version !== 1) {
    throw new Error('This version cannot open the previous journal.');
  }
  const archive = emptyArchive();
  const accounts = readAccounts(old.accounts ?? {});
  for (const account of accounts) {
    if (!account?.id || !account.profile || !Array.isArray(account.reports)) {
      throw new Error('A saved skate profile could not be opened.');
    }
    archive.accounts[account.id] = {
      ...account,
      reports: account.reports.map(report => ({...report, subject: readSubject(report.subject)})),
    };
  }
  archive.follows = old.follows ?? [];
  archive.comments = old.comments ?? [];
  archive.activity = old.activity ?? [];
  archive.receipts = old.receipts ?? {};
  archive.retiredAccounts = old.retiredAccounts ?? [];
  return archive;
}
