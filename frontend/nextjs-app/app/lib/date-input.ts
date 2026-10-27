/** datetime-local controls need local wall time; API timestamps remain ISO UTC. */
export function localDateTimeInputValue(date=new Date()):string{
  return new Date(date.getTime()-date.getTimezoneOffset()*60000).toISOString().slice(0,16);
}
