export function obj2tags(obj: Record<string, any>) {
  return Object.entries(obj).map(([key, value]) => ({
    name: key,
    value: tostring(value),
  }));
}

function tostring(value: any) {
  if (typeof value === "object") {
    return JSON.stringify(value);
  }
  return String(value);
}