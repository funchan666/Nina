import {useRef, useState} from 'react';
import {errorText, useFlow} from '../navigation';

export function useMutation() {
  const flow = useFlow();
  const lock = useRef(false);
  const [busy, setBusy] = useState(false);

  async function run(action: () => Promise<unknown>, done?: () => void) {
    if (lock.current) {
      return;
    }
    lock.current = true;
    setBusy(true);
    try {
      await action();
      done?.();
    } catch (error) {
      flow.notice(errorText(error));
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }
  return {busy, run};
}
