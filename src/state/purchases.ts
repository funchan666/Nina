import {platform} from '../native';
import type {VerifiedPurchase} from '../native';
import {library} from './library';

export async function deliver(transaction: VerifiedPurchase) {
  if (!(await library.recordPurchase(transaction))) {
    return false;
  }
  await platform('finishPurchase', {transactionID: transaction.id});
  return true;
}
