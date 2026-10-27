import {test,expect} from '@playwright/test';
import {localDateTimeInputValue} from '../app/lib/date-input';

test('transaction date inputs preserve local time across timezone and day boundaries',()=>{
  const east=new Date('2026-10-05T20:10:00Z');east.getTimezoneOffset=()=>-330;
  expect(localDateTimeInputValue(east)).toBe('2026-10-06T01:40');
  const west=new Date('2026-10-06T01:10:00Z');west.getTimezoneOffset=()=>480;
  expect(localDateTimeInputValue(west)).toBe('2026-10-05T17:10');
});
