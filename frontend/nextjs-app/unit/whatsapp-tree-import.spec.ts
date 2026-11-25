import {test,expect} from '@playwright/test';
import {whatsappGroupName,whatsappMemberNames} from '../app/lib/whatsapp-tree-import';
test('extracts only timestamped speakers across Android and iOS; ignores bodies and system events',()=>{
 const text='25/11/2026, 10:30 - Asha: Hello\nNot a member: message continuation\n25/11/2026, 10:31 - Ravi added Someone\n[25/11/2026, 10:32:05 PM] Ravi: Secret body\n25/11/2026, 10:33 - ASHA: Again\n[2026-11-25, 10:34:05] +91 90000 00000: Hello';
 expect(whatsappMemberNames(text,'chat')).toEqual(['Asha','Ravi','+91 90000 00000']);
 expect(whatsappMemberNames('Unrecognized date format: message','chat')).toEqual([]);
});
test('member lists retain Unicode, deduplicate and keep group names',()=>{
 expect(whatsappMemberNames(' Asha \nASHA\nరవి\n\nMeera','members')).toEqual(['Asha','రవి','Meera']);
 expect(whatsappGroupName('WhatsApp Chat with Hyderabad Cycle Club.txt')).toBe('Hyderabad Cycle Club');
 expect(()=>whatsappMemberNames('x'.repeat(5_000_001),'members')).toThrow('5 MB');
});
