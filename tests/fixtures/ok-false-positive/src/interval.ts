export interface Interface {
  interval: number;
  internal: boolean;
}

export function intervalLength(item: Interface): number {
  const internal = item.internal;
  return item.interval + (internal ? 1 : 0);
}

const lucid = "clear";
const note = "zeitgeist and poltergeist and international Intercom";
const myInter = 1;
function internal(interval: Interface): Interface {
  return interval;
}
